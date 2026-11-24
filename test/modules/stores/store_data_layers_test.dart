import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/modules/stores/external/datasources/drift_store_local_datasource.dart';
import 'package:kym/modules/stores/infra/datasources/store_local_datasource.dart';
import 'package:kym/modules/stores/infra/models/store_model.dart';
import 'package:kym/modules/stores/infra/repositories/store_list_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockStoreLocalDataSource extends Mock implements StoreLocalDataSource {}

void main() {
  group('StoreListRepositoryImpl', () {
    late MockStoreLocalDataSource dataSource;
    late StoreListRepositoryImpl repository;

    setUp(() {
      dataSource = MockStoreLocalDataSource();
      repository = StoreListRepositoryImpl(dataSource);
    });

    test('converte os modelos em entidades', () async {
      when(dataSource.watchStores).thenAnswer(
        (_) => Stream.value(const [
          StoreModel(
            id: ' s1 ',
            name: ' Loja Centro ',
            code: ' L1 ',
            address: ' Rua da Matriz, 1 ',
            city: ' ',
            active: false,
            openOrders: 3,
            overdueOrders: 2,
            preventiveOrders: 1,
            correctiveOrders: 2,
          ),
        ]),
      );

      final store = (await repository.watchStores().first).single;

      expect(store.id, 's1');
      expect(store.name, 'Loja Centro');
      expect(store.code, 'L1');
      expect(store.address, 'Rua da Matriz, 1');
      expect(store.city, isNull);
      expect(store.isActive, isFalse);
      expect(store.openOrders, 3);
      expect(store.overdueOrders, 2);
      expect(store.preventiveOrders, 1);
      expect(store.correctiveOrders, 2);
    });

    test('ignora registros sem id ou sem nome', () async {
      when(dataSource.watchStores).thenAnswer(
        (_) => Stream.value(const [
          StoreModel(id: '', name: 'Sem id'),
          StoreModel(id: 's2', name: '  '),
          StoreModel(id: 's3', name: 'Válida'),
        ]),
      );

      final stores = await repository.watchStores().first;

      expect(stores.map((s) => s.id), ['s3']);
    });

    test('contagens negativas viram zero', () async {
      when(dataSource.watchStores).thenAnswer(
        (_) => Stream.value(const [
          StoreModel(
            id: 's1',
            name: 'Loja',
            openOrders: -2,
            overdueOrders: -1,
            preventiveOrders: -3,
            correctiveOrders: -4,
          ),
        ]),
      );

      final store = (await repository.watchStores().first).single;

      expect(store.openOrders, 0);
      expect(store.overdueOrders, 0);
      expect(store.preventiveOrders, 0);
      expect(store.correctiveOrders, 0);
    });

    test('propaga o erro do datasource', () async {
      when(dataSource.watchStores).thenAnswer(
        (_) => Stream<List<StoreModel>>.error(StateError('falha no banco')),
      );

      await expectLater(repository.watchStores().first, throwsStateError);
    });
  });

  group('DriftStoreLocalDataSource', () {
    final now = DateTime(2026, 11, 16, 12);
    late AppDatabase db;
    late DriftStoreLocalDataSource dataSource;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = DriftStoreLocalDataSource.withClock(db, () => now);
    });

    tearDown(() => db.close());

    Future<void> insertStore(
      String id, {
      String? name,
      String? city,
      bool active = true,
    }) {
      return db.storesDao.upsert(
        StoresCompanion.insert(
          id: id,
          name: name ?? 'Loja $id',
          qrToken: 'qr-$id',
          code: Value('C-$id'),
          address: Value('Rua $id, 1'),
          city: Value(city),
          active: Value(active),
        ),
      );
    }

    Future<void> insertEquipment(String storeId) {
      return db.equipmentsDao.upsert(
        EquipmentsCompanion.insert(
          id: 'eq-$storeId',
          storeId: storeId,
          name: 'Freezer',
          qrToken: 'qr-eq-$storeId',
        ),
      );
    }

    Future<void> insertOrder(
      String id,
      String storeId,
      OrderStatus status, {
      OrderType type = OrderType.corretiva,
      DateTime? scheduledFor,
    }) {
      return db.maintenanceOrdersDao.upsert(
        MaintenanceOrdersCompanion.insert(
          id: id,
          equipmentId: 'eq-$storeId',
          storeId: storeId,
          type: type,
          status: Value(status),
          scheduledFor: Value(scheduledFor),
        ),
      );
    }

    test('conta só ordens abertas, agendadas e em andamento', () async {
      await insertStore('s1', city: 'Recife');
      await insertEquipment('s1');
      await insertOrder('o1', 's1', OrderStatus.aberta);
      await insertOrder('o2', 's1', OrderStatus.agendada);
      await insertOrder('o3', 's1', OrderStatus.emAndamento);
      await insertOrder('o4', 's1', OrderStatus.concluida);
      await insertOrder('o5', 's1', OrderStatus.cancelada);

      final store = (await dataSource.watchStores().first).single;

      expect(store.openOrders, 3);
      expect(store.city, 'Recife');
      expect(store.code, 'C-s1');
      expect(store.address, 'Rua s1, 1');
    });

    test('separa atrasadas, preventivas e corretivas', () async {
      await insertStore('s1');
      await insertEquipment('s1');
      await insertOrder(
        'o1',
        's1',
        OrderStatus.agendada,
        type: OrderType.preventiva,
        scheduledFor: DateTime(2026, 11, 10),
      );
      await insertOrder(
        'o2',
        's1',
        OrderStatus.agendada,
        type: OrderType.preventiva,
        scheduledFor: DateTime(2026, 11, 20),
      );
      await insertOrder('o3', 's1', OrderStatus.aberta);
      await insertOrder(
        'o4',
        's1',
        OrderStatus.concluida,
        type: OrderType.preventiva,
        scheduledFor: DateTime(2026, 11, 1),
      );

      final store = (await dataSource.watchStores().first).single;

      expect(store.openOrders, 3);
      expect(store.overdueOrders, 1);
      expect(store.preventiveOrders, 2);
      expect(store.correctiveOrders, 1);
    });

    test('ordem sem data não conta como atrasada', () async {
      await insertStore('s1');
      await insertEquipment('s1');
      await insertOrder('o1', 's1', OrderStatus.aberta);

      expect((await dataSource.watchStores().first).single.overdueOrders, 0);
    });

    test('loja sem ordens aparece com zero, uma linha por loja', () async {
      await insertStore('s1');
      await insertStore('s2');
      await insertEquipment('s1');
      await insertOrder('o1', 's1', OrderStatus.aberta);
      await insertOrder('o2', 's1', OrderStatus.aberta);

      final stores = await dataSource.watchStores().first;
      final counts = {for (final s in stores) s.id: s.openOrders};

      expect(counts, {'s1': 2, 's2': 0});
    });

    test('devolve também as inativas, marcadas', () async {
      await insertStore('s1', active: false);

      final stores = await dataSource.watchStores().first;

      expect(stores.single.active, isFalse);
    });

    test('banco vazio devolve lista vazia', () async {
      expect(await dataSource.watchStores().first, isEmpty);
    });

    test('o construtor padrão usa o relógio do sistema', () async {
      await insertStore('s1');

      final stores = await DriftStoreLocalDataSource(db).watchStores().first;

      expect(stores.single.overdueOrders, 0);
    });

    test('ordem vira atrasada com a passagem do tempo, sem mudar o banco', (
    ) async {
      var clock = DateTime(2026, 11, 16, 12);
      final ticking = DriftStoreLocalDataSource.withClock(
        db,
        () => clock,
        recountEvery: const Duration(milliseconds: 20),
      );
      await insertStore('s1');
      await insertEquipment('s1');
      await insertOrder(
        'o1',
        's1',
        OrderStatus.agendada,
        scheduledFor: DateTime(2026, 11, 16, 14),
      );

      final emissions = <int>[];
      final subscription = ticking.watchStores().listen(
        (stores) => emissions.add(stores.single.overdueOrders),
      );
      await pumpEventQueue();
      expect(emissions, [0]);

      clock = DateTime(2026, 11, 16, 15);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await subscription.cancel();

      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });

    test('cancelar a assinatura para a recontagem', () async {
      var reads = 0;
      final ticking = DriftStoreLocalDataSource.withClock(db, () {
        reads++;
        return now;
      }, recountEvery: const Duration(milliseconds: 10));

      final subscription = ticking.watchStores().listen((_) {});
      await pumpEventQueue();
      await subscription.cancel();
      final readsAtCancel = reads;

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(reads, readsAtCancel);
    });

    test('reemite quando uma ordem muda', () async {
      await insertStore('s1');
      await insertEquipment('s1');
      final emissions = <int>[];
      final subscription = dataSource.watchStores().listen(
        (stores) => emissions.add(stores.single.openOrders),
      );
      await pumpEventQueue();

      await insertOrder('o1', 's1', OrderStatus.aberta);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [0, 1]);
    });
  });
}
