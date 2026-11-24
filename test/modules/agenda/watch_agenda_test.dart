import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart' as local;
import 'package:kym/app/database/seed/fake_data_seeder.dart';
import 'package:kym/modules/agenda/domain/usecases/watch_agenda.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart';
import 'package:kym/modules/orders/infra/repositories/order_repository_impl.dart';

void main() {
  late local.AppDatabase db;
  late WatchAgenda watchAgenda;

  setUp(() async {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    watchAgenda = WatchAgenda(
      OrderRepositoryImpl(db, idGenerator: () => 'nova-ordem'),
    );
    await FakeDataSeeder(db).seedIfEmpty();
  });

  tearDown(() => db.close());

  test(
    'técnico vê só as ordens atribuídas a ele, com equipamento e loja',
    () async {
      final items = await watchAgenda(
        userId: FakeDataSeeder.tecnicoId,
        role: UserRole.tecnico,
      ).first;

      // f2, f3 e as duas preventivas atrasadas da Loja Centro (f4 e f5).
      expect(items, hasLength(4));
      expect(
        items.every((i) => i.order.assignedTo == FakeDataSeeder.tecnicoId),
        isTrue,
      );
      final vitrine = items.firstWhere(
        (i) => i.equipmentName == 'Ar-condicionado Vitrine',
      );
      expect(vitrine.storeName, 'Loja Boa Viagem');
      expect(vitrine.order.type, OrderType.preventiva);
    },
  );

  test('gestor vê todas, inclusive o chamado sem técnico', () async {
    final items = await watchAgenda(
      userId: FakeDataSeeder.gestorId,
      role: UserRole.gestor,
    ).first;

    expect(items, hasLength(5));
    expect(items.map((i) => i.equipmentName), contains('Câmara Fria'));
  });

  test('ordena pela data, com as sem data primeiro', () async {
    final items = await watchAgenda(
      userId: FakeDataSeeder.gestorId,
      role: UserRole.gestor,
    ).first;

    expect(items.first.order.scheduledFor, isNull);
    expect(
      items[1].order.scheduledFor!.isBefore(items[2].order.scheduledFor!),
      isTrue,
    );
  });

  test('canceladas ficam de fora', () async {
    await (db.update(
      db.maintenanceOrders,
    )..where((o) => o.id.equals('00000000-0000-4000-8000-0000000000f2'))).write(
      const local.MaintenanceOrdersCompanion(
        status: Value(local.OrderStatus.cancelada),
      ),
    );

    final items = await watchAgenda(
      userId: FakeDataSeeder.tecnicoId,
      role: UserRole.tecnico,
    ).first;

    expect(items, hasLength(3));
    expect(
      items.map((i) => i.order.id),
      isNot(contains('00000000-0000-4000-8000-0000000000f2')),
    );
  });

  test('atualiza sozinho quando uma ordem nova chega', () async {
    final stream = watchAgenda(
      userId: FakeDataSeeder.tecnicoId,
      role: UserRole.tecnico,
    );
    final counts = <int>[];
    final subscription = stream.listen((items) => counts.add(items.length));
    await pumpEventQueue();

    await db.maintenanceOrdersDao.upsert(
      local.MaintenanceOrdersCompanion.insert(
        id: 'nova-ordem',
        equipmentId: '00000000-0000-4000-8000-0000000000e1',
        storeId: '00000000-0000-4000-8000-0000000000a1',
        type: local.OrderType.preventiva,
        scheduledFor: Value(DateTime(2026, 11, 25)),
        assignedTo: const Value(FakeDataSeeder.tecnicoId),
      ),
    );
    await pumpEventQueue();

    expect(counts, [4, 5]);
    await subscription.cancel();
  });
}
