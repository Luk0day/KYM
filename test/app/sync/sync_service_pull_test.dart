import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/app/sync/incremental_puller.dart';
import 'package:kym/app/sync/sync_exception.dart';
import 'package:kym/app/sync/sync_service.dart';

import 'fake_remote_sync_datasource.dart';
import 'server_rows.dart';

void main() {
  late AppDatabase db;
  late FakeRemoteSyncDataSource remote;
  late SyncService service;
  final now = DateTime(2026, 11, 18, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = FakeRemoteSyncDataSource();
    service = SyncService(
      outbox: db.outboxDao,
      remote: remote,
      puller: IncrementalPuller(db: db, remote: remote, clock: () => now),
      clock: () => now,
    );
  });

  tearDown(() async {
    await service.dispose();
    await remote.sessionController.close();
    await db.close();
  });

  test('envia a outbox antes de baixar', () async {
    remote.serverUpsert('stores', serverStore('s1'));
    await db.outboxDao.enqueue(
      userId: 'u1',
      operation: OutboxOperation.update,
      entity: OutboxEntity.store,
      entityId: 's-x',
      payload: {'name': 'X'},
    );
    final order = <String>[];
    remote
      ..onPush = ((_) => order.add('push'))
      ..onFetch = ((table, _) => order.add('fetch $table'));

    final result = await service.sync();

    expect(order.first, 'push');
    expect(order.skip(1), everyElement(startsWith('fetch')));
    expect(result.pulled!.written, 1);
    expect(await db.storesDao.findById('s1'), isNotNull);
  });

  test('sem rede no envio, não baixa', () async {
    await db.outboxDao.enqueue(
      userId: 'u1',
      operation: OutboxOperation.update,
      entity: OutboxEntity.store,
      entityId: 's-x',
      payload: {'name': 'X'},
    );
    remote.onPush = (_) => throw const SyncNetworkException('offline');

    final result = await service.sync();

    expect(result.interrupted, isTrue);
    expect(result.pulled, isNull);
    expect(remote.fetches, isEmpty);
  });

  test('sem rede na baixada, a rodada fica interrompida', () async {
    remote.onFetch = (_, _) => throw const SyncNetworkException('caiu');

    final result = await service.sync();

    expect(result.interrupted, isTrue);
    expect(result.pulled, isNull);
  });

  test('erro do servidor na baixada vira pullError', () async {
    remote.onFetch = (_, _) =>
        throw const SyncServerException('coluna não existe', code: '42703');

    final result = await service.sync();

    expect(result.interrupted, isFalse);
    expect(result.pullError, '[42703] coluna não existe');
    expect(result.toString(), contains('pullError'));
  });

  test('fullPull reconcilia, e o pedido sobrevive a uma interrupção', () async {
    remote
      ..serverUpsert('stores', serverStore('s1'))
      ..serverUpsert('stores', serverStore('s2'))
      ..serverUpsert('equipment', serverEquipment('e1', 's1'));
    await service.sync();
    remote.rows['stores']!.remove('s2');

    // Incremental: não vê exclusões.
    var result = await service.sync();
    expect(result.pulled!.deleted, 0);

    // Pedido de reconciliação interrompido pela rede: fica para a próxima.
    remote.onFetch = (_, _) => throw const SyncNetworkException('caiu');
    result = await service.sync(fullPull: true);
    expect(result.interrupted, isTrue);

    remote.onFetch = null;
    result = await service.sync();
    expect(result.pulled!.deleted, 1);
    expect(await db.storesDao.findById('s2'), isNull);

    // Atendido: a próxima volta a ser incremental.
    result = await service.sync();
    expect(result.pulled!.deleted, 0);
  });

  test('a baixada sabe quem está logado', () async {
    remote.serverUpsert('stores', serverStore('s1'));
    remote.userId = 'u9';

    await service.sync();

    expect((await db.pullDao.stateFor('stores'))!.userId, 'u9');
  });

  test('soma o que foi baixado nas voltas extras', () {
    const a = SyncResult(pulled: PullResult(written: 2));
    const b = SyncResult(pulled: PullResult(written: 3));
    expect((a + b).pulled!.written, 5);
    expect((a + const SyncResult()).pulled!.written, 2);
    expect((const SyncResult() + const SyncResult()).pulled, isNull);
  });
}
