import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/app/sync/incremental_puller.dart';
import 'package:kym/app/sync/infra/remote_sync_datasource.dart';
import 'package:kym/app/sync/sync_exception.dart';

import 'fake_remote_sync_datasource.dart';
import 'server_rows.dart';

void main() {
  late AppDatabase db;
  late FakeRemoteSyncDataSource remote;
  late DateTime now;

  IncrementalPuller puller({int pageSize = 500}) => IncrementalPuller(
        db: db,
        remote: remote,
        clock: () => now,
        pageSize: pageSize,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = FakeRemoteSyncDataSource();
    now = DateTime(2026, 11, 18, 12);
  });

  tearDown(() async {
    await remote.sessionController.close();
    await db.close();
  });

  void seedServer() {
    remote
      ..serverUpsert('stores', serverStore('s1'))
      ..serverUpsert('stores', serverStore('s2', at: 1))
      ..serverUpsert('equipment', serverEquipment('e1', 's1'))
      ..serverUpsert('maintenance_orders', serverOrder('o1', 'e1', 's1'))
      ..serverUpsert('photos', serverPhoto('p1', 'o1'));
  }

  group('primeiro pull', () {
    test('traz tudo, na ordem das chaves estrangeiras', () async {
      seedServer();

      final result = await puller().pull();

      expect(result.written, 5);
      expect(result.deleted, 0);
      expect(
        remote.fetches.map((f) => f.$1),
        ['stores', 'equipment', 'maintenance_orders', 'photos'],
      );
      expect(remote.fetches.every((f) => f.$2 == null), isTrue);

      final store = await db.storesDao.findById('s1');
      expect(store!.name, 'Loja s1');
      expect(store.latitude, -8.05);
      expect(store.updatedAt!.isAtSameMomentAs(DateTime.parse(t0)), isTrue);
      expect(store.syncedAt, now);

      final equipment = await db.equipmentsDao.findById('e1');
      expect(equipment!.serialNumber, 'SN-e1');
      expect(equipment.installedAt, DateTime(2026, 1, 15));

      final order = await db.maintenanceOrdersDao.findById('o1');
      expect(order!.type, OrderType.corretiva);
      expect(order.status, OrderStatus.aberta);
      expect(order.scheduledFor, DateTime(2026, 11, 20));

      final photo = await db.photosDao.findById('p1');
      expect(photo!.kind, PhotoKind.chamado);
      expect(photo.uploadStatus, PhotoUploadStatus.uploaded);

      final state = await db.pullDao.stateFor('stores');
      expect(state!.cursor, stamp(1));
      expect(state.lastFullPullAt, now);
    });

    test('tabela vazia no servidor não grava marca', () async {
      await puller().pull();

      final state = await db.pullDao.stateFor('stores');
      expect(state!.cursor, isNull);
      expect(state.lastFullPullAt, now);
    });
  });

  group('pull incremental', () {
    test('duas vezes seguidas não duplica', () async {
      seedServer();
      await puller().pull();
      await puller().pull();

      expect(await db.storesDao.listAll(), hasLength(2));
      expect(await db.equipmentsDao.listAll(), hasLength(1));
    });

    test('começa um pouco antes da marca, com >=', () async {
      seedServer();
      await puller().pull();
      remote.fetches.clear();

      await puller().pull();

      final (table, after) = remote.fetches.first;
      expect(table, 'stores');
      expect(after!.id, isNull);
      expect(
        DateTime.parse(after.updatedAt),
        DateTime.parse(stamp(1)).subtract(const Duration(seconds: 30)),
      );
    });

    test('registro alterado no servidor é atualizado localmente', () async {
      seedServer();
      await puller().pull();

      remote.serverUpsert(
        'equipment',
        serverEquipment('e1', 's1', at: 60, status: 'parado'),
      );
      final result = await puller().pull();

      expect((await db.equipmentsDao.findById('e1'))!.status, 'parado');
      expect(result.deleted, 0);
      expect((await db.pullDao.stateFor('equipment'))!.cursor, stamp(60));
    });

    test('pagina por (updated_at, id) sem pular linhas do mesmo instante',
        () async {
      for (final id in ['s1', 's2', 's3', 's4', 's5']) {
        remote.serverUpsert('stores', serverStore(id));
      }

      final result = await puller(pageSize: 2).pull();

      expect(result.written, 5);
      expect(await db.storesDao.listAll(), hasLength(5));
      final storeFetches =
          remote.fetches.where((f) => f.$1 == 'stores').toList();
      expect(storeFetches, hasLength(3));
      expect(storeFetches[1].$2!.id, 's2');
      expect(storeFetches[2].$2!.id, 's4');
    });

    test('a marca não volta atrás', () async {
      await db.pullDao.saveCursor('stores', stamp(100));
      await db.pullDao.markFullPull('stores', now);
      remote.serverUpsert('stores', serverStore('s1', at: 90));

      await puller().pull();

      expect((await db.pullDao.stateFor('stores'))!.cursor, stamp(100));
      expect(await db.storesDao.findById('s1'), isNotNull);
    });
  });

  group('pendências locais', () {
    test('não sobrescreve registro com operação na outbox', () async {
      seedServer();
      await puller().pull();
      await (db.update(db.maintenanceOrders)..where((o) => o.id.equals('o1')))
          .write(
        const MaintenanceOrdersCompanion(
          status: Value(OrderStatus.emAndamento),
        ),
      );
      await db.outboxDao.enqueue(
        operation: OutboxOperation.update,
        entity: OutboxEntity.maintenanceOrder,
        entityId: 'o1',
        payload: {'status': 'em_andamento'},
      );
      remote.serverUpsert(
        'maintenance_orders',
        serverOrder('o1', 'e1', 's1', at: 60, status: 'cancelada'),
      );

      final result = await puller().pull();

      expect(
        (await db.maintenanceOrdersDao.findById('o1'))!.status,
        OrderStatus.emAndamento,
      );
      expect(result.skipped, greaterThanOrEqualTo(1));
    });

    test('o pai de uma pendência continua sendo atualizado', () async {
      seedServer();
      await puller().pull();
      await db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.maintenanceOrder,
        entityId: 'o-local',
        payload: {'id': 'o-local', 'store_id': 's1', 'equipment_id': 'e1'},
      );
      remote.serverUpsert('stores', serverStore('s1', at: 60, name: 'Nova'));

      await puller().pull();

      expect((await db.storesDao.findById('s1'))!.name, 'Nova');
    });

    test('foto pendente segura a loja da ordem na reconciliação', () async {
      seedServer();
      await puller().pull();
      await db.photosDao.upsert(
        PhotosCompanion.insert(
          id: 'p-local',
          orderId: 'o1',
          storagePath: 'orders/o1/p-local.jpg',
        ),
      );
      await db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.photo,
        entityId: 'p-local',
        payload: {'id': 'p-local', 'order_id': 'o1'},
      );
      // O técnico perdeu acesso à loja s1 (e a tudo dentro dela).
      remote.rows['stores']!.remove('s1');
      remote.rows['equipment']!.clear();
      remote.rows['maintenance_orders']!.clear();
      remote.rows['photos']!.clear();

      await puller().pull(full: true);

      // Sem a proteção transitiva, apagar s1 levaria e1, o1 e p-local junto.
      expect(await db.storesDao.findById('s1'), isNotNull);
      expect(await db.equipmentsDao.findById('e1'), isNotNull);
      expect(await db.maintenanceOrdersDao.findById('o1'), isNotNull);
      expect(await db.photosDao.findById('p-local'), isNotNull);
      expect(await db.photosDao.findById('p1'), isNull);
      expect(await db.storesDao.findById('s2'), isNotNull);
    });

    test('foto já no aparelho mantém arquivo e estado de envio', () async {
      seedServer();
      await puller().pull();
      await (db.update(db.photos)..where((p) => p.id.equals('p1'))).write(
        const PhotosCompanion(
          localPath: Value('/fotos/p1.jpg'),
          uploadStatus: Value(PhotoUploadStatus.pending),
        ),
      );
      remote.serverUpsert('photos', {
        ...serverPhoto('p1', 'o1', at: 60),
        'kind': 'antes',
      });

      await puller().pull();

      final photo = await db.photosDao.findById('p1');
      expect(photo!.kind, PhotoKind.antes);
      expect(photo.localPath, '/fotos/p1.jpg');
      expect(photo.uploadStatus, PhotoUploadStatus.pending);
    });
  });

  group('linhas problemáticas', () {
    test('órfã (pai não visível) é pulada', () async {
      remote.serverUpsert('equipment', serverEquipment('e9', 's-invisivel'));

      final result = await puller().pull();

      expect(result.written, 0);
      expect(result.skipped, 1);
      expect(await db.equipmentsDao.findById('e9'), isNull);
    });

    test('inválida é pulada e o resto é gravado', () async {
      remote
        ..serverUpsert('stores', serverStore('s1'))
        ..serverUpsert('stores', {...serverStore('s2'), 'name': null})
        ..serverUpsert('equipment', serverEquipment('e1', 's1'))
        ..serverUpsert(
          'maintenance_orders',
          {...serverOrder('o1', 'e1', 's1'), 'status': 'inexistente'},
        );

      final result = await puller().pull();

      expect(result.written, 2);
      expect(result.skipped, 2);
      expect(await db.storesDao.findById('s2'), isNull);
      expect(await db.maintenanceOrdersDao.findById('o1'), isNull);
    });

    test('linha sem updated_at interrompe com FormatException', () async {
      remote
        ..serverUpsert('stores', serverStore('s1'))
        ..mapResult = (table, rows) => [
              for (final r in rows) {...r, 'updated_at': 'x'},
            ];

      await expectLater(puller().pull(), throwsFormatException);
    });
  });

  group('reconciliação completa', () {
    test('apaga o que sumiu do servidor, menos o que tem pendência', () async {
      seedServer();
      remote
        ..serverUpsert('stores', serverStore('s3'))
        ..serverUpsert('equipment', serverEquipment('e3', 's3'));
      await puller().pull();

      // Pedido local ainda não enviado, na loja s2.
      await db.equipmentsDao.upsert(
        EquipmentsCompanion.insert(
          id: 'e-local',
          storeId: 's2',
          name: 'Novo',
          qrToken: 'qr-local',
        ),
      );
      await db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.equipment,
        entityId: 'e-local',
        payload: {'id': 'e-local', 'store_id': 's2'},
      );
      // O técnico perdeu acesso às lojas s2 e s3.
      remote.rows['stores']!
        ..remove('s2')
        ..remove('s3');
      remote.rows['equipment']!.remove('e3');

      final incremental = await puller().pull();
      expect(incremental.deleted, 0);
      expect(await db.storesDao.findById('s3'), isNotNull);

      final full = await puller().pull(full: true);

      // Só s3 é apagada direto; e3 vai junto pelo cascade. s2 fica porque é
      // pai de uma pendência.
      expect(full.deleted, 1);
      expect(await db.storesDao.findById('s3'), isNull);
      expect(await db.equipmentsDao.findById('e3'), isNull);
      expect(await db.storesDao.findById('s2'), isNotNull);
      expect(await db.equipmentsDao.findById('e-local'), isNotNull);
      expect(await db.storesDao.findById('s1'), isNotNull);
    });

    test('roda sozinha depois do intervalo', () async {
      seedServer();
      await puller().pull();
      remote.rows['stores']!.remove('s2');
      remote.fetches.clear();

      now = now.add(const Duration(hours: 25));
      final result = await puller().pull();

      expect(remote.fetches.first.$2, isNull);
      expect(result.deleted, 1);
      expect((await db.pullDao.stateFor('stores'))!.lastFullPullAt, now);
    });
  });

  group('falhas', () {
    test('rede caindo no meio guarda a marca das páginas já gravadas',
        () async {
      for (final id in ['s1', 's2', 's3']) {
        remote.serverUpsert('stores', serverStore(id, at: int.parse(id[1])));
      }
      var calls = 0;
      remote.onFetch = (table, after) {
        if (table == 'stores' && ++calls == 2) {
          throw const SyncNetworkException('caiu');
        }
      };

      await expectLater(
        puller(pageSize: 2).pull(),
        throwsA(isA<SyncNetworkException>()),
      );

      expect(await db.storesDao.listAll(), hasLength(2));
      expect((await db.pullDao.stateFor('stores'))!.cursor, stamp(2));
      expect((await db.pullDao.stateFor('stores'))!.lastFullPullAt, isNull);

      remote.onFetch = null;
      await puller(pageSize: 2).pull();
      expect(await db.storesDao.listAll(), hasLength(3));
    });
  });

  group('PullDao', () {
    test('clearState faz o próximo pull trazer tudo', () async {
      seedServer();
      await puller().pull();

      expect(await db.pullDao.clearState(), 4);
      remote.fetches.clear();
      await puller().pull();

      expect(remote.fetches.every((f) => f.$2 == null), isTrue);
    });

    test('existingIds consulta em blocos', () async {
      await db.batch((b) {
        for (var i = 0; i < 1200; i++) {
          b.insert(
            db.stores,
            StoresCompanion.insert(id: 's$i', name: 'L', qrToken: 'q$i'),
          );
        }
      });

      final found = await db.pullDao.existingIds(
        db.stores,
        [for (var i = 0; i < 1300; i++) 's$i'],
      );

      expect(found, hasLength(1200));
      expect(
        await db.pullDao.deleteMissing(db.stores, {'s0'}),
        1199,
      );
    });
  });

  test('PullResult soma e descreve', () {
    const a = PullResult(written: 1, skipped: 2, deleted: 3);
    expect(
      (a + a).toString(),
      'PullResult(written: 2, skipped: 4, deleted: 6)',
    );
    expect(const PullCursor(updatedAt: t0, id: 'x').toString(),
        'PullCursor($t0, x)');
  });
}
