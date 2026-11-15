import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart' as local;
import 'package:kym/app/database/seed/fake_data_seeder.dart';
import 'package:kym/modules/equipment/infra/repositories/equipment_repository_impl.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart';
import 'package:kym/modules/orders/infra/repositories/order_repository_impl.dart';
import 'package:kym/modules/stores/infra/repositories/store_repository_impl.dart';

void main() {
  late local.AppDatabase db;
  late StoreRepositoryImpl stores;
  late EquipmentRepositoryImpl equipments;
  late OrderRepositoryImpl orders;
  var nextId = 0;

  setUp(() async {
    nextId = 0;
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    stores = StoreRepositoryImpl(db.storesDao);
    equipments = EquipmentRepositoryImpl(db.equipmentsDao);
    orders = OrderRepositoryImpl(
      db,
      idGenerator: () => 'order-${++nextId}',
      clock: () => DateTime.utc(2026, 11, 14, 10),
    );
    await FakeDataSeeder(db).seedIfEmpty();
  });

  tearDown(() => db.close());

  group('seed do modo fake', () {
    test('cria 3 lojas e 10 equipamentos', () async {
      expect((await stores.watchAll().first), hasLength(3));
      expect((await equipments.watchAll().first), hasLength(10));
    });

    test('não duplica ao rodar de novo', () async {
      expect(await FakeDataSeeder(db).seedIfEmpty(), isFalse);
      expect((await equipments.watchAll().first), hasLength(10));
    });

    test('não enfileira nada na outbox', () async {
      expect(await db.outboxDao.listPending(), isEmpty);
    });
  });

  group('StoreRepository', () {
    test('lista por nome e mapeia para entidade de domínio', () async {
      final list = await stores.watchAll().first;
      expect(list.map((s) => s.name), [
        'Loja Boa Viagem',
        'Loja Centro',
        'Loja Shopping',
      ]);
      expect(
        list.firstWhere((s) => s.name == 'Loja Centro').hasCoordinates,
        isTrue,
      );
      expect(
        list.firstWhere((s) => s.name == 'Loja Shopping').hasCoordinates,
        isFalse,
      );
    });

    test('achar por id e por qrToken', () async {
      final centro = (await stores.watchAll().first).firstWhere(
        (s) => s.name == 'Loja Centro',
      );
      expect((await stores.findById(centro.id))?.name, 'Loja Centro');
      expect((await stores.findByQrToken(centro.qrToken))?.id, centro.id);
    });

    test('id e qrToken inexistentes dão null', () async {
      expect(await stores.findById('nope'), isNull);
      expect(await stores.findByQrToken('nope'), isNull);
      expect(await stores.watchById('nope').first, isNull);
    });

    test('o stream reemite quando o banco muda', () async {
      final emissions = <int>[];
      final sub = stores.watchAll().listen((l) => emissions.add(l.length));
      await pumpEventQueue();

      await db.storesDao.upsert(
        local.StoresCompanion.insert(id: 's-x', name: 'Nova', qrToken: 'qr-x'),
      );
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions, [3, 4]);
    });
  });

  group('EquipmentRepository', () {
    late String centroId;

    setUp(() async {
      centroId = (await stores.watchAll().first)
          .firstWhere((s) => s.name == 'Loja Centro')
          .id;
    });

    test('lista só os equipamentos da loja, por nome', () async {
      final list = await equipments.watchByStore(centroId).first;
      expect(list, hasLength(4));
      expect(list.every((e) => e.storeId == centroId), isTrue);
      final names = list.map((e) => e.name).toList();
      expect(names, [...names]..sort());
    });

    test('achar por qrToken e id', () async {
      final eq = (await equipments.watchByStore(centroId).first).first;
      expect((await equipments.findByQrToken(eq.qrToken))?.id, eq.id);
      expect((await equipments.findById(eq.id))?.name, eq.name);
      expect(await equipments.findByQrToken('nope'), isNull);
    });
  });

  group('OrderRepository', () {
    late String storeId;
    late String equipmentId;

    setUp(() async {
      storeId = (await stores.watchAll().first)
          .firstWhere((s) => s.name == 'Loja Centro')
          .id;
      equipmentId = (await equipments.watchByStore(storeId).first).first.id;
    });

    test('create grava a ordem e a outbox juntas', () async {
      final created = await orders.create(
        NewOrder(
          equipmentId: equipmentId,
          storeId: storeId,
          type: OrderType.corretiva,
          description: 'Não gela',
          openedBy: FakeDataSeeder.lojistaId,
        ),
      );

      expect(created.id, 'order-1');
      expect(created.status, OrderStatus.aberta);
      expect(created.type, OrderType.corretiva);
      expect(created.createdAt.toUtc(), DateTime.utc(2026, 11, 14, 10));

      final pending = await db.outboxDao.listPending();
      expect(pending, hasLength(1));
      expect(pending.single.entity, local.OutboxEntity.maintenanceOrder);
      expect(pending.single.operation, local.OutboxOperation.insert);
      expect(pending.single.entityId, 'order-1');

      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload['id'], 'order-1');
      expect(payload['equipment_id'], equipmentId);
      expect(payload['store_id'], storeId);
      expect(payload['type'], 'corretiva');
      expect(payload['status'], 'aberta');
      expect(payload['opened_by'], FakeDataSeeder.lojistaId);
      expect(payload.containsKey('assigned_to'), isFalse);
    });

    test('se a gravação falha, nem a ordem nem a outbox ficam', () async {
      await expectLater(
        orders.create(
          NewOrder(
            equipmentId: 'equipamento-inexistente',
            storeId: storeId,
            type: OrderType.corretiva,
          ),
        ),
        throwsA(anything),
      );

      expect(await orders.findById('order-1'), isNull);
      expect(await db.outboxDao.listPending(), isEmpty);
    });

    test('se a outbox falha, a ordem é desfeita', () async {
      // Item da outbox já ocupando o id que o próximo create vai usar não
      // conflita (autoincrement), então força a falha derrubando a tabela.
      await db.customStatement('DROP TABLE outbox');

      await expectLater(
        orders.create(
          NewOrder(
            equipmentId: equipmentId,
            storeId: storeId,
            type: OrderType.corretiva,
          ),
        ),
        throwsA(anything),
      );

      expect(await orders.findById('order-1'), isNull);
    });

    test('watchByEquipment e watchByStore trazem a ordem criada', () async {
      await orders.create(
        NewOrder(
          equipmentId: equipmentId,
          storeId: storeId,
          type: OrderType.preventiva,
          status: OrderStatus.agendada,
          scheduledFor: DateTime.utc(2026, 12, 1, 9),
          assignedTo: FakeDataSeeder.tecnicoId,
        ),
      );

      final byEquipment = await orders.watchByEquipment(equipmentId).first;
      expect(byEquipment.map((o) => o.id), contains('order-1'));
      final byStore = await orders.watchByStore(storeId).first;
      expect(byStore.map((o) => o.id), contains('order-1'));
      expect(
        (await orders.findById('order-1'))?.scheduledFor?.toUtc(),
        DateTime.utc(2026, 12, 1, 9),
      );
    });

    test('mapeia todos os status do banco para o domínio', () async {
      final all = await orders.watchAll().first;
      expect(
        all.map((o) => o.status),
        containsAll([
          OrderStatus.aberta,
          OrderStatus.agendada,
          OrderStatus.concluida,
        ]),
      );
    });
  });

  test('lista com 200 equipamentos abre rápido', () async {
    final storeId = (await stores.watchAll().first).first.id;
    await db.batch((b) {
      b.insertAll(db.equipments, [
        for (var i = 0; i < 200; i++)
          local.EquipmentsCompanion.insert(
            id: 'bulk-$i',
            storeId: storeId,
            name: 'Equipamento $i',
            qrToken: 'qr-bulk-$i',
          ),
      ]);
    });

    final watch = Stopwatch()..start();
    final list = await equipments.watchByStore(storeId).first;
    watch.stop();

    expect(list.length, greaterThanOrEqualTo(200));
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
