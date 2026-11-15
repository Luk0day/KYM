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
            city: ' ',
            active: false,
            openOrders: 3,
          ),
        ]),
      );

      final stores = await repository.watchStores().first;

      expect(stores.single.id, 's1');
      expect(stores.single.name, 'Loja Centro');
      expect(stores.single.code, 'L1');
      expect(stores.single.city, isNull);
      expect(stores.single.isActive, isFalse);
      expect(stores.single.openOrders, 3);
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

    test('contagem negativa vira zero', () async {
      when(dataSource.watchStores).thenAnswer(
        (_) => Stream.value(const [
          StoreModel(id: 's1', name: 'Loja', openOrders: -2),
        ]),
      );

      expect((await repository.watchStores().first).single.openOrders, 0);
    });

    test('propaga o erro do datasource', () async {
      when(dataSource.watchStores).thenAnswer(
        (_) => Stream<List<StoreModel>>.error(StateError('falha no banco')),
      );

      await expectLater(repository.watchStores().first, throwsStateError);
    });
  });

  group('DriftStoreLocalDataSource', () {
    late AppDatabase db;
    late DriftStoreLocalDataSource dataSource;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = DriftStoreLocalDataSource(db);
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
      OrderStatus status,
    ) {
      return db.maintenanceOrdersDao.upsert(
        MaintenanceOrdersCompanion.insert(
          id: id,
          equipmentId: 'eq-$storeId',
          storeId: storeId,
          type: OrderType.corretiva,
          status: Value(status),
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

      final stores = await dataSource.watchStores().first;

      expect(stores.single.openOrders, 3);
      expect(stores.single.city, 'Recife');
      expect(stores.single.code, 'C-s1');
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

    test('reemite quando uma ordem muda', () async {
      await insertStore('s1');
      await insertEquipment('s1');
      final emissions = <int>[];
      final subscription = dataSource
          .watchStores()
          .listen((stores) => emissions.add(stores.single.openOrders));
      await pumpEventQueue();

      await insertOrder('o1', 's1', OrderStatus.aberta);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [0, 1]);
    });
  });
}
