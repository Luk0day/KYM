import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> enqueue(String entityId) => db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.photo,
        entityId: entityId,
        payload: {'id': entityId},
      );

  Future<OutboxEntry> entry(int id) async => (await db.outboxDao.findById(id))!;

  Future<void> failTimes(int id, int times) async {
    for (var i = 0; i < times; i++) {
      await db.outboxDao.markFailed(id, 'erro $i');
    }
  }

  test('listRetryable traz pendentes e falhos com tentativas, em ordem',
      () async {
    final pending = await enqueue('a');
    final retryable = await enqueue('b');
    final exhausted = await enqueue('c');
    final done = await enqueue('d');
    final processing = await enqueue('e');
    await failTimes(retryable, 2);
    await failTimes(exhausted, 5);
    await db.outboxDao.markDone(done);
    await db.outboxDao.markProcessing(processing);

    final items = await db.outboxDao.listRetryable(maxAttempts: 5);
    expect(items.map((e) => e.id), [pending, retryable]);

    final dead = await db.outboxDao.listExhausted(maxAttempts: 5);
    expect(dead.map((e) => e.id), [exhausted]);
  });

  test('só o envio que termina grava a hora da tentativa', () async {
    final failed = await enqueue('a');
    final done = await enqueue('b');
    final processing = await enqueue('c');
    final at = DateTime(2026, 11, 18, 9, 30);

    await db.outboxDao.markFailed(failed, 'erro', at: at);
    await db.outboxDao.markDone(done, at: at);
    await db.outboxDao.markProcessing(processing);

    expect((await entry(failed)).lastAttemptAt, at);
    expect((await entry(done)).lastAttemptAt, at);
    final inFlight = await entry(processing);
    expect(inFlight.status, OutboxStatus.processing);
    expect(inFlight.lastAttemptAt, isNull);
  });

  test('release devolve o estado anterior sem somar tentativa', () async {
    final id = await enqueue('a');
    final at = DateTime(2026, 11, 18, 9, 30);
    await db.outboxDao.markFailed(id, 'erro', at: at);
    await db.outboxDao.markProcessing(id);

    await db.outboxDao.release(id, OutboxStatus.failed);

    final item = await entry(id);
    expect(item.status, OutboxStatus.failed);
    expect(item.attempts, 1);
    expect(item.lastAttemptAt, at);
  });

  test('resetProcessing devolve à fila o que ficou no meio', () async {
    final a = await enqueue('a');
    final b = await enqueue('b');
    await db.outboxDao.markProcessing(a);

    expect(await db.outboxDao.resetProcessing(), 1);

    expect((await entry(a)).status, OutboxStatus.pending);
    expect((await entry(b)).status, OutboxStatus.pending);
  });

  test('resetFailed zera tentativas e erro', () async {
    final id = await enqueue('a');
    await failTimes(id, 5);

    expect(await db.outboxDao.resetFailed(), 1);

    final item = await entry(id);
    expect(item.status, OutboxStatus.pending);
    expect(item.attempts, 0);
    expect(item.lastError, isNull);
  });

  test('purgeDone apaga só os concluídos antigos', () async {
    final cutoff = DateTime(2026, 11, 11);
    final oldDone = await enqueue('a');
    final recentDone = await enqueue('b');
    final oldPending = await enqueue('c');
    final legacyDone = await enqueue('d');
    await db.outboxDao.markDone(oldDone, at: DateTime(2026, 11, 1));
    await db.outboxDao.markDone(recentDone, at: DateTime(2026, 11, 17));
    await (db.update(db.outbox)..where((o) => o.id.equals(oldPending))).write(
      OutboxCompanion(createdAt: Value(DateTime(2026, 10, 1))),
    );
    // Item sem lastAttemptAt (criado antes da v2): vale a data de criação.
    await (db.update(db.outbox)..where((o) => o.id.equals(legacyDone))).write(
      OutboxCompanion(
        status: const Value(OutboxStatus.done),
        createdAt: Value(DateTime(2026, 10, 1)),
      ),
    );

    expect(await db.outboxDao.purgeDone(olderThan: cutoff), 2);

    expect(await db.outboxDao.findById(oldDone), isNull);
    expect(await db.outboxDao.findById(legacyDone), isNull);
    expect(await db.outboxDao.findById(recentDone), isNotNull);
    expect(await db.outboxDao.findById(oldPending), isNotNull);
  });

  test('watchPendingCount conta o que ainda não chegou ao servidor', () async {
    final counts = <int>[];
    final sub = db.outboxDao.watchPendingCount().listen(counts.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    final a = await enqueue('a');
    await pumpEventQueue();
    final b = await enqueue('b');
    await pumpEventQueue();
    await db.outboxDao.markFailed(a, 'erro');
    await pumpEventQueue();
    await db.outboxDao.markDone(b);
    await pumpEventQueue();

    expect(counts, [0, 1, 2, 1]);
  });

  test('watchFailedCount e watchLastId', () async {
    expect(await db.outboxDao.watchFailedCount().first, 0);
    expect(await db.outboxDao.watchLastId().first, isNull);

    await enqueue('a');
    final b = await enqueue('b');
    await db.outboxDao.markFailed(b, 'erro');

    expect(await db.outboxDao.watchFailedCount().first, 1);
    expect(await db.outboxDao.watchLastId().first, b);
  });

  test('markDoneAndSynced marca o item e o registro na mesma transação',
      () async {
    await db.storesDao.upsert(
      StoresCompanion.insert(id: 's1', name: 'Loja', qrToken: 'qr'),
    );
    final id = await db.outboxDao.enqueue(
      operation: OutboxOperation.insert,
      entity: OutboxEntity.store,
      entityId: 's1',
      payload: {'id': 's1'},
    );
    final at = DateTime(2026, 11, 18, 12);

    await db.outboxDao.markDoneAndSynced(await entry(id), at);

    expect((await entry(id)).status, OutboxStatus.done);
    expect((await db.storesDao.findById('s1'))!.syncedAt, at);
  });

  test('migração v1 → v2 adiciona lastAttemptAt sem perder a fila', () async {
    final legacy = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
            CREATE TABLE outbox (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              operation TEXT NOT NULL,
              entity TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              payload TEXT NOT NULL,
              status TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              last_error TEXT NULL,
              created_at INTEGER NOT NULL
            );
          ''');
          raw.execute('''
            INSERT INTO outbox
              (operation, entity, entity_id, payload, status, created_at)
            VALUES ('insert', 'photo', 'p1', '{}', 'pending', 1763000000);
          ''');
          raw.execute('PRAGMA user_version = 1;');
        },
      ),
    );
    addTearDown(legacy.close);

    final items = await legacy.outboxDao.listPending();

    expect(items, hasLength(1));
    expect(items.single.entityId, 'p1');
    expect(items.single.lastAttemptAt, isNull);
    await legacy.outboxDao.markFailed(items.single.id, 'erro');
    expect(
      (await legacy.outboxDao.findById(items.single.id))!.lastAttemptAt,
      isNotNull,
    );
  });
}
