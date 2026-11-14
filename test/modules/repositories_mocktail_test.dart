import 'dart:convert';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart' as local;
import 'package:kym/app/database/daos/equipments_dao.dart';
import 'package:kym/app/database/daos/maintenance_orders_dao.dart';
import 'package:kym/app/database/daos/outbox_dao.dart';
import 'package:kym/app/database/daos/stores_dao.dart';
import 'package:kym/modules/equipment/infra/repositories/equipment_repository_impl.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart';
import 'package:kym/modules/orders/infra/repositories/order_repository_impl.dart';
import 'package:kym/modules/stores/infra/repositories/store_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockStoresDao extends Mock implements StoresDao {}

class MockEquipmentsDao extends Mock implements EquipmentsDao {}

class MockOrdersDao extends Mock implements MaintenanceOrdersDao {}

class MockOutboxDao extends Mock implements OutboxDao {}

class MockDb extends Mock implements local.AppDatabase {}

local.Store _storeRow({
  String id = 's1',
  String qr = 'qr-s1',
  double? lat,
  double? lng,
}) => local.Store(
  id: id,
  name: 'Loja $id',
  code: null,
  address: 'Rua A',
  city: 'Recife',
  latitude: lat,
  longitude: lng,
  qrToken: qr,
  active: true,
  createdAt: DateTime.utc(2026, 11, 1),
  syncedAt: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(local.MaintenanceOrdersCompanion());
    registerFallbackValue(local.OutboxOperation.insert);
    registerFallbackValue(local.OutboxEntity.maintenanceOrder);
  });

  group('StoreRepository com DAO mockado', () {
    late MockStoresDao dao;
    late StoreRepositoryImpl repo;

    setUp(() {
      dao = MockStoresDao();
      repo = StoreRepositoryImpl(dao);
    });

    // PASSA COM CERTEZA
    test(
      'passa com certeza: converte a linha em entidade de domínio',
      () async {
        when(() => dao.findByQrToken('qr-s1'))
            .thenAnswer((_) async => _storeRow(lat: -8.06, lng: -34.87));

        final store = await repo.findByQrToken('qr-s1');

        expect(store?.id, 's1');
        expect(store?.name, 'Loja s1');
        expect(store?.hasCoordinates, isTrue);
        verify(() => dao.findByQrToken('qr-s1')).called(1);
      },
    );

    // QUASE FALHA: valor no limite que um `if (lat)` ingênuo reprovaria.
    test(
      'quase falha: latitude e longitude 0.0 contam como coordenadas',
      () async {
        when(() => dao.findById('s1'))
            .thenAnswer((_) async => _storeRow(lat: 0.0, lng: 0.0));

        expect((await repo.findById('s1'))?.hasCoordinates, isTrue);
      },
    );

    // QUASE PASSA: parece ter coordenadas, mas falta uma metade.
    test('quase passa: só latitude, sem longitude, não é coordenada', () async {
      when(() => dao.findById('s1'))
          .thenAnswer((_) async => _storeRow(lat: -8.06));

      expect((await repo.findById('s1'))?.hasCoordinates, isFalse);
    });

    // NÃO PASSA COM CERTEZA
    test(
      'não passa com certeza: erro do banco sobe para quem chamou',
      () async {
        when(() => dao.findById(any()))
            .thenThrow(StateError('banco corrompido'));

        expect(() => repo.findById('s1'), throwsStateError);
      },
    );

    test('não passa com certeza: loja inexistente devolve null', () async {
      when(() => dao.findByQrToken('nope')).thenAnswer((_) async => null);
      when(() => dao.watchById('nope')).thenAnswer((_) => Stream.value(null));

      expect(await repo.findByQrToken('nope'), isNull);
      expect(await repo.watchById('nope').first, isNull);
    });

    test('o stream de lojas é convertido item a item', () async {
      when(() => dao.watchAll()).thenAnswer(
        (_) => Stream.value([_storeRow(id: 'a'), _storeRow(id: 'b')]),
      );

      final list = await repo.watchAll().first;
      expect(list.map((s) => s.id), ['a', 'b']);
    });
  });

  group('EquipmentRepository com DAO mockado', () {
    late MockEquipmentsDao dao;
    late EquipmentRepositoryImpl repo;

    local.Equipment row({String status = 'operando'}) => local.Equipment(
      id: 'e1',
      storeId: 's1',
      name: 'Freezer',
      category: 'Refrigeração',
      brand: null,
      model: null,
      serialNumber: null,
      qrToken: 'qr-e1',
      status: status,
      installedAt: null,
      notes: null,
      createdAt: DateTime.utc(2026, 11, 1),
      syncedAt: null,
    );

    setUp(() {
      dao = MockEquipmentsDao();
      repo = EquipmentRepositoryImpl(dao);
    });

    test('passa com certeza: lista da loja chega mapeada', () async {
      when(() => dao.watchByStore('s1'))
          .thenAnswer((_) => Stream.value([row(), row(status: 'parado')]));

      final list = await repo.watchByStore('s1').first;

      expect(list.map((e) => e.status), ['operando', 'parado']);
      expect(list.first.storeId, 's1');
    });

    test('quase falha: status desconhecido não derruba a leitura', () async {
      when(() => dao.findById('e1'))
          .thenAnswer((_) async => row(status: 'valor_novo_do_servidor'));

      expect((await repo.findById('e1'))?.status, 'valor_novo_do_servidor');
    });

    test(
      'quase passa: qrToken com caixa diferente não é reaproveitado',
      () async {
        when(() => dao.findByQrToken('QR-E1')).thenAnswer((_) async => null);

        expect(await repo.findByQrToken('QR-E1'), isNull);
        verifyNever(() => dao.findByQrToken('qr-e1'));
      },
    );

    test('não passa com certeza: falha do stream chega ao ouvinte', () async {
      when(() => dao.watchByStore('s1')).thenAnswer(
        (_) => Stream<List<local.Equipment>>.error(StateError('falhou')),
      );

      expect(repo.watchByStore('s1'), emitsError(isA<StateError>()));
    });
  });

  group('OrderRepository com mocks', () {
    late MockDb db;
    late MockOrdersDao orders;
    late MockOutboxDao outbox;
    late OrderRepositoryImpl repo;

    const draft = NewOrder(
      equipmentId: 'e1',
      storeId: 's1',
      type: OrderType.corretiva,
      description: 'Não gela',
      openedBy: 'u1',
    );

    setUp(() {
      db = MockDb();
      orders = MockOrdersDao();
      outbox = MockOutboxDao();
      when(() => db.maintenanceOrdersDao).thenReturn(orders);
      when(() => db.outboxDao).thenReturn(outbox);
      // Executa a transação de verdade, só sem banco por baixo.
      when(() => db.transaction<void>(any())).thenAnswer(
        (i) => (i.positionalArguments.first as Future<void> Function())(),
      );
      when(() => orders.upsert(any())).thenAnswer((_) async {});
      when(
        () => outbox.enqueue(
          operation: any(named: 'operation'),
          entity: any(named: 'entity'),
          entityId: any(named: 'entityId'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async => 1);
      repo = OrderRepositoryImpl(
        db,
        idGenerator: () => 'o1',
        clock: () => DateTime.utc(2026, 11, 14, 10),
      );
    });

    // Depois do create, `findById` lê a ordem gravada.
    void stubFind() => when(() => orders.findById('o1')).thenAnswer(
      (_) async => local.MaintenanceOrder(
        id: 'o1',
        equipmentId: 'e1',
        storeId: 's1',
        type: local.OrderType.corretiva,
        status: local.OrderStatus.aberta,
        description: 'Não gela',
        notes: null,
        scheduledFor: null,
        openedBy: 'u1',
        assignedTo: null,
        startedAt: null,
        completedAt: null,
        createdAt: DateTime.utc(2026, 11, 14, 10),
        updatedAt: DateTime.utc(2026, 11, 14, 10),
        syncedAt: null,
      ),
    );

    test('passa com certeza: grava a ordem e enfileira uma vez cada', () async {
      stubFind();

      final created = await repo.create(draft);

      expect(created.id, 'o1');
      verify(() => orders.upsert(any())).called(1);
      final payload =
          verify(
                () => outbox.enqueue(
                  operation: local.OutboxOperation.insert,
                  entity: local.OutboxEntity.maintenanceOrder,
                  entityId: 'o1',
                  payload: captureAny(named: 'payload'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(payload['type'], 'corretiva');
      expect(payload['status'], 'aberta');
      expect(payload['opened_by'], 'u1');
    });

    test(
      'quase falha: ordem sem descrição nem agendamento sai sem esses campos',
      () async {
        stubFind();

        await repo.create(
          const NewOrder(
            equipmentId: 'e1',
            storeId: 's1',
            type: OrderType.preventiva,
          ),
        );

        final payload =
            verify(
                  () => outbox.enqueue(
                    operation: any(named: 'operation'),
                    entity: any(named: 'entity'),
                    entityId: any(named: 'entityId'),
                    payload: captureAny(named: 'payload'),
                  ),
                ).captured.single
                as Map<String, Object?>;
        expect(payload.containsKey('description'), isFalse);
        expect(payload.containsKey('scheduled_for'), isFalse);
        expect(payload['type'], 'preventiva');
      },
    );

    test('quase passa: a ordem foi gravada, mas a outbox falhou, então create falha', () async {
      when(
        () => outbox.enqueue(
          operation: any(named: 'operation'),
          entity: any(named: 'entity'),
          entityId: any(named: 'entityId'),
          payload: any(named: 'payload'),
        ),
      ).thenThrow(StateError('disco cheio'));

      await expectLater(repo.create(draft), throwsStateError);

      // O upsert chegou a ser chamado dentro da transação; quem desfaz é o
      // banco (coberto com banco real em repositories_test.dart).
      verify(() => orders.upsert(any())).called(1);
      verifyNever(() => orders.findById(any()));
    });

    test(
      'não passa com certeza: erro ao gravar a ordem não enfileira nada',
      () async {
        when(() => orders.upsert(any())).thenThrow(StateError('FK violada'));

        await expectLater(repo.create(draft), throwsStateError);

        verifyNever(
          () => outbox.enqueue(
            operation: any(named: 'operation'),
            entity: any(named: 'entity'),
            entityId: any(named: 'entityId'),
            payload: any(named: 'payload'),
          ),
        );
      },
    );
  });

  // ALEATÓRIO: entradas sorteadas com semente fixa (reproduzível). Se falhar,
  // a semente aparece na mensagem.
  group('teste aleatório com banco real', () {
    const seed = 18;

    test(
      'toda ordem criada tem exatamente 1 item na outbox coerente (seed $seed)',
      () async {
        final random = Random(seed);
        final db = local.AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await db.storesDao.upsert(
          local.StoresCompanion.insert(id: 's1', name: 'L', qrToken: 'qs'),
        );
        await db.equipmentsDao.upsert(
          local.EquipmentsCompanion.insert(
            id: 'e1',
            storeId: 's1',
            name: 'E',
            qrToken: 'qe',
          ),
        );
        var n = 0;
        final repo = OrderRepositoryImpl(db, idGenerator: () => 'o${++n}');

        const total = 50;
        final expected =
            <String, ({OrderType type, OrderStatus status, String? desc})>{};
        for (var i = 0; i < total; i++) {
          final type =
              OrderType.values[random.nextInt(OrderType.values.length)];
          final status =
              OrderStatus.values[random.nextInt(OrderStatus.values.length)];
          final desc = random.nextBool()
              ? String.fromCharCodes(
                  List.generate(
                    random.nextInt(60),
                    (_) => 32 + random.nextInt(95),
                  ),
                )
              : null;
          final created = await repo.create(
            NewOrder(
              equipmentId: 'e1',
              storeId: 's1',
              type: type,
              status: status,
              description: desc,
            ),
          );
          expected[created.id] = (type: type, status: status, desc: desc);
        }

        final entries = await db.outboxDao.listPending();
        expect(entries, hasLength(total), reason: 'seed=$seed');
        for (final entry in entries) {
          final want = expected[entry.entityId]!;
          final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
          expect(payload['type'], want.type.name, reason: 'seed=$seed');
          expect(payload['status'], switch (want.status) {
            OrderStatus.emAndamento => 'em_andamento',
            final s => s.name,
          }, reason: 'seed=$seed');
          expect(payload['description'], want.desc, reason: 'seed=$seed');
          final stored = await repo.findById(entry.entityId);
          expect(stored?.type, want.type, reason: 'seed=$seed');
          expect(stored?.status, want.status, reason: 'seed=$seed');
          expect(stored?.description, want.desc, reason: 'seed=$seed');
        }
      },
    );
  });
}
