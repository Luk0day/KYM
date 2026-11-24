import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/app/sync/infra/remote_sync_datasource.dart';
import 'package:kym/app/sync/retry_policy.dart';
import 'package:kym/app/sync/sync_exception.dart';
import 'package:kym/app/sync/sync_service.dart';

import 'fake_remote_sync_datasource.dart';

void main() {
  late AppDatabase db;
  late FakeRemoteSyncDataSource remote;
  late DateTime now;
  late SyncService service;

  SyncService buildService({RetryPolicy retryPolicy = const RetryPolicy()}) =>
      SyncService(
        outbox: db.outboxDao,
        remote: remote,
        retryPolicy: retryPolicy,
        clock: () => now,
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = FakeRemoteSyncDataSource();
    now = DateTime(2026, 11, 18, 10);
    service = buildService();

    await db.storesDao.upsert(
      StoresCompanion.insert(id: 's1', name: 'Loja 1', qrToken: 'qr-s1'),
    );
    await db.equipmentsDao.upsert(
      EquipmentsCompanion.insert(
        id: 'e1',
        storeId: 's1',
        name: 'Freezer',
        qrToken: 'qr-e1',
      ),
    );
  });

  tearDown(() async {
    await service.dispose();
    await remote.sessionController.close();
    await db.close();
  });

  Future<void> insertLocalOrder(String id) =>
      db.maintenanceOrdersDao.upsert(
        MaintenanceOrdersCompanion.insert(
          id: id,
          equipmentId: 'e1',
          storeId: 's1',
          type: OrderType.corretiva,
        ),
      );

  Future<int> enqueueOrder(
    String id, {
    OutboxOperation operation = OutboxOperation.insert,
    Map<String, Object?>? payload,
    String? userId = 'u1',
  }) =>
      db.outboxDao.enqueue(
        operation: operation,
        entity: OutboxEntity.maintenanceOrder,
        entityId: id,
        userId: userId,
        payload: payload ??
            {'id': id, 'equipment_id': 'e1', 'store_id': 's1', 'type': 'corretiva'},
      );

  Future<int> enqueuePhoto(
    String id,
    String orderId, {
    String? userId = 'u1',
  }) =>
      db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.photo,
        entityId: id,
        userId: userId,
        payload: {'id': id, 'order_id': orderId, 'storage_path': 'x.jpg'},
      );

  Future<OutboxEntry> entry(int id) async => (await db.outboxDao.findById(id))!;

  group('envio em ordem', () {
    test('envia na ordem de criação, marca done e grava o syncedAt', () async {
      await insertLocalOrder('o1');
      await insertLocalOrder('o2');
      final a = await enqueueOrder('o1');
      final b = await enqueueOrder('o2');
      final c = await enqueueOrder(
        'o1',
        operation: OutboxOperation.update,
        payload: {'status': 'concluida'},
      );

      final result = await service.sync();

      expect(result.sent, 3);
      expect(result.failed, 0);
      expect(result.interrupted, isFalse);
      expect(remote.pushedIds, ['o1', 'o2', 'o1']);
      expect(remote.pushed.map((op) => op.kind), [
        RemoteOperationKind.insert,
        RemoteOperationKind.insert,
        RemoteOperationKind.update,
      ]);
      expect(remote.rows['maintenance_orders']!['o1']!['status'], 'concluida');
      for (final id in [a, b, c]) {
        expect((await entry(id)).status, OutboxStatus.done);
      }
      final synced = await db.maintenanceOrdersDao.findById('o1');
      expect(synced!.syncedAt, now);
    });

    test('segue a ordem de criação mesmo se o relógio do aparelho voltar',
        () async {
      await enqueueOrder('o1');
      final update = await enqueueOrder(
        'o1',
        operation: OutboxOperation.update,
        payload: {'status': 'concluida'},
      );
      // O relógio voltou entre as duas operações: o update ficou "mais velho".
      await (db.update(db.outbox)..where((o) => o.id.equals(update))).write(
        OutboxCompanion(createdAt: Value(DateTime(2020))),
      );

      await service.sync();

      expect(remote.pushed.map((op) => op.kind), [
        RemoteOperationKind.insert,
        RemoteOperationKind.update,
      ]);
    });

    test('exclusão não procura registro local para marcar', () async {
      final id = await db.outboxDao.enqueue(
        operation: OutboxOperation.delete,
        entity: OutboxEntity.photo,
        entityId: 'p-apagada',
        userId: 'u1',
        payload: {},
      );

      final result = await service.sync();

      expect(result.sent, 1);
      expect(remote.pushed.single.kind, RemoteOperationKind.delete);
      expect((await entry(id)).status, OutboxStatus.done);
    });

    test('marca o syncedAt da loja e do equipamento', () async {
      await db.outboxDao.enqueue(
        operation: OutboxOperation.update,
        entity: OutboxEntity.store,
        entityId: 's1',
        userId: 'u1',
        payload: {'name': 'Loja nova'},
      );
      await db.outboxDao.enqueue(
        operation: OutboxOperation.update,
        entity: OutboxEntity.equipment,
        entityId: 'e1',
        userId: 'u1',
        payload: {'status': 'parado'},
      );

      await service.sync();

      expect((await db.storesDao.findById('s1'))!.syncedAt, now);
      expect((await db.equipmentsDao.findById('e1'))!.syncedAt, now);
    });

    test('fila vazia não envia nada', () async {
      final result = await service.sync();
      expect(result.sent, 0);
      expect(remote.pushed, isEmpty);
      expect(result.nextRetryAt, isNull);
    });
  });

  group('erro de rede', () {
    test('para a fila sem gastar tentativa', () async {
      final a = await enqueueOrder('o1');
      final b = await enqueueOrder('o2');
      remote.onPush = (_) => throw const SyncNetworkException('offline');

      final result = await service.sync();

      expect(result.interrupted, isTrue);
      expect(result.interruptedBy!.message, 'offline');
      expect(remote.pushedIds, ['o1']);
      final first = await entry(a);
      expect(first.status, OutboxStatus.pending);
      expect(first.attempts, 0);
      expect((await entry(b)).status, OutboxStatus.pending);
    });

    test('item falho volta a falho, com as mesmas tentativas e a mesma espera',
        () async {
      final a = await enqueueOrder('o1');
      final failedAt = now.subtract(const Duration(minutes: 5));
      await db.outboxDao.markFailed(a, 'erro antigo', at: failedAt);
      remote.onPush = (_) => throw const SyncNetworkException('offline');

      await service.sync();

      expect(remote.pushed, hasLength(1));
      final item = await entry(a);
      expect(item.status, OutboxStatus.failed);
      expect(item.attempts, 1);
      expect(item.lastAttemptAt, failedAt);
    });

    test('reenvio depois da queda não duplica o registro', () async {
      await insertLocalOrder('o1');
      final a = await enqueueOrder('o1');
      var drops = 1;
      remote.afterApply = (_) {
        if (drops-- > 0) throw const SyncNetworkException('caiu');
      };

      await service.sync();
      expect((await entry(a)).status, OutboxStatus.pending);

      final result = await service.sync();

      expect(result.sent, 1);
      expect(remote.pushedIds, ['o1', 'o1']);
      expect(remote.rows['maintenance_orders'], hasLength(1));
      expect((await entry(a)).status, OutboxStatus.done);
    });

    test('troca de usuário: só vão os itens de quem está logado', () async {
      final fromA = await enqueueOrder('o1', userId: 'a');
      // Foto de B que aponta para a ordem de A: espera a ordem subir.
      final photoOfB = await enqueuePhoto('p1', 'o1', userId: 'b');
      final fromB = await enqueueOrder('o2', userId: 'b');
      remote.userId = 'b';

      final result = await service.sync();

      expect(remote.pushedIds, ['o2']);
      expect(result.skipped, 2);
      expect(result.failed, 0);
      final waiting = await entry(fromA);
      expect(waiting.status, OutboxStatus.pending);
      expect(waiting.attempts, 0);
      expect((await entry(photoOfB)).status, OutboxStatus.pending);
      expect((await entry(fromB)).status, OutboxStatus.done);

      // A entra de novo: a ordem dele sobe.
      remote.userId = 'a';
      await service.sync();
      expect(remote.pushedIds, ['o2', 'o1']);
      expect((await entry(fromA)).status, OutboxStatus.done);
    });

    test('item sem dono (anterior à v2) vai com quem estiver logado', () async {
      final legacy = await enqueueOrder('o1', userId: null);

      await service.sync();

      expect((await entry(legacy)).status, OutboxStatus.done);
    });

    test('sem sessão não envia nada', () async {
      await enqueueOrder('o1');
      remote.session = false;

      final result = await service.sync();

      expect(result.interrupted, isTrue);
      expect(remote.pushed, isEmpty);
    });
  });

  group('erro do servidor', () {
    test('marca falho com a mensagem e segue a fila', () async {
      final a = await enqueueOrder('o1');
      final b = await enqueueOrder('o2');
      remote.onPush = (op) {
        if (op.id == 'o1') {
          throw const SyncServerException('violou RLS', code: '42501');
        }
      };

      final result = await service.sync();

      expect(result.sent, 1);
      expect(result.failed, 1);
      final failed = await entry(a);
      expect(failed.status, OutboxStatus.failed);
      expect(failed.attempts, 1);
      expect(failed.lastError, '[42501] violou RLS');
      expect(failed.lastAttemptAt, now);
      expect((await entry(b)).status, OutboxStatus.done);
      expect(result.nextRetryAt, now.add(const Duration(seconds: 30)));
    });

    test('erro inesperado também marca falho e segue', () async {
      final a = await enqueueOrder('o1');
      final b = await enqueueOrder('o2');
      remote.onPush = (op) {
        if (op.id == 'o1') throw StateError('bug');
      };

      await service.sync();

      expect((await entry(a)).lastError, contains('erro inesperado'));
      expect((await entry(b)).status, OutboxStatus.done);
    });

    test('payload inválido marca falho sem chamar o servidor', () async {
      final id = await enqueueOrder('o1');
      await (db.update(db.outbox)..where((o) => o.id.equals(id)))
          .write(const OutboxCompanion(payload: Value('[1, 2]')));

      final result = await service.sync();

      expect(result.failed, 1);
      expect(remote.pushed, isEmpty);
      expect((await entry(id)).lastError, startsWith('payload inválido'));
    });

    test('payload inválido espera a vez como qualquer item falho', () async {
      final id = await enqueueOrder('o1');
      await (db.update(db.outbox)..where((o) => o.id.equals(id)))
          .write(const OutboxCompanion(payload: Value('[1, 2]')));
      await service.sync();

      now = now.add(const Duration(seconds: 1));
      final result = await service.sync();

      expect(result.skipped, 1);
      expect((await entry(id)).attempts, 1);
    });
  });

  group('dependências', () {
    test('pula os itens do registro falho e os que apontam para ele', () async {
      await enqueueOrder('o1');
      final update = await enqueueOrder(
        'o1',
        operation: OutboxOperation.update,
        payload: {'status': 'concluida'},
      );
      final photo = await enqueuePhoto('p1', 'o1');
      final other = await enqueueOrder('o2');
      remote.onPush = (op) {
        if (op.id == 'o1') throw const SyncServerException('recusado');
      };

      final result = await service.sync();

      expect(result.failed, 1);
      expect(result.skipped, 2);
      expect(remote.pushedIds, ['o1', 'o2']);
      expect((await entry(update)).status, OutboxStatus.pending);
      expect((await entry(photo)).status, OutboxStatus.pending);
      expect((await entry(other)).status, OutboxStatus.done);
    });

    test('item que esgotou as tentativas segura os dependentes', () async {
      final order = await enqueueOrder('o1');
      for (var i = 0; i < 5; i++) {
        await db.outboxDao.markFailed(order, 'recusado');
      }
      final photo = await enqueuePhoto('p1', 'o1');

      final result = await service.sync();

      expect(remote.pushed, isEmpty);
      expect(result.skipped, 1);
      expect((await entry(order)).attempts, 5);
      expect((await entry(photo)).status, OutboxStatus.pending);
    });
  });

  group('novas tentativas', () {
    test('espera a vez antes de reenviar um item falho', () async {
      final a = await enqueueOrder('o1');
      remote.onPush = (_) => throw const SyncServerException('recusado');
      await service.sync();
      remote.onPush = null;

      now = now.add(const Duration(seconds: 10));
      var result = await service.sync();
      expect(result.skipped, 1);
      expect(remote.pushed, hasLength(1));
      expect(result.nextRetryAt, DateTime(2026, 11, 18, 10, 0, 30));

      now = now.add(const Duration(seconds: 20));
      result = await service.sync();
      expect(result.sent, 1);
      expect((await entry(a)).status, OutboxStatus.done);
    });

    test('para de tentar depois do limite', () async {
      service = buildService(
        retryPolicy: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration.zero,
        ),
      );
      final a = await enqueueOrder('o1');
      remote.onPush = (_) => throw const SyncServerException('recusado');

      await service.sync();
      final second = await service.sync();
      final third = await service.sync();

      expect(remote.pushed, hasLength(2));
      expect(second.nextRetryAt, isNull);
      expect(third.sent + third.failed + third.skipped, 0);
      final item = await entry(a);
      expect(item.status, OutboxStatus.failed);
      expect(item.attempts, 2);
    });

    test('item vencido preso a um pai que ainda espera não pede tentativa '
        'imediata', () async {
      final order = await enqueueOrder('o1');
      final photo = await enqueuePhoto('p1', 'o1');
      // Pai: 2 falhas, a última há 10 s; espera 1 min, então volta em 50 s.
      await db.outboxDao.markFailed(order, 'recusado');
      await db.outboxDao.markFailed(
        order,
        'recusado',
        at: now.subtract(const Duration(seconds: 10)),
      );
      // Filho: 1 falha há 10 min, já poderia tentar de novo.
      await db.outboxDao.markFailed(
        photo,
        'sem o pai',
        at: now.subtract(const Duration(minutes: 10)),
      );

      final result = await service.sync();

      expect(remote.pushed, isEmpty);
      expect(result.nextRetryAt, now.add(const Duration(seconds: 50)));
    });

    test('item preso a um pai que esgotou as tentativas não agenda nada',
        () async {
      final order = await enqueueOrder('o1');
      for (var i = 0; i < 5; i++) {
        await db.outboxDao.markFailed(order, 'recusado');
      }
      final photo = await enqueuePhoto('p1', 'o1');
      await db.outboxDao.markFailed(
        photo,
        'sem o pai',
        at: now.subtract(const Duration(minutes: 10)),
      );

      final result = await service.sync();

      expect(remote.pushed, isEmpty);
      expect(result.nextRetryAt, isNull);
    });

    test('resetFailed devolve o item à fila', () async {
      final a = await enqueueOrder('o1');
      remote.onPush = (_) => throw const SyncServerException('recusado');
      await service.sync();
      remote.onPush = null;

      await db.outboxDao.resetFailed();
      final result = await service.sync();

      expect(result.sent, 1);
      expect((await entry(a)).status, OutboxStatus.done);
    });
  });

  group('robustez', () {
    test('item que ficou em processing volta a ser enviado', () async {
      final a = await enqueueOrder('o1');
      await db.outboxDao.markProcessing(a);

      final result = await service.sync();

      expect(result.sent, 1);
      expect((await entry(a)).status, OutboxStatus.done);
    });

    test('não roda duas vezes ao mesmo tempo e pega o que chegou no meio',
        () async {
      await enqueueOrder('o1');
      final gate = Completer<void>();
      remote.onPush = (op) => op.id == 'o1' ? gate.future : null;

      final first = service.sync();
      await pumpEventQueue();
      expect(service.isRunning, isTrue);
      await enqueueOrder('o2');
      final second = service.sync();
      gate.complete();

      final results = await Future.wait([first, second]);

      expect(identical(results[0], results[1]), isTrue);
      expect(results[0].sent, 2);
      expect(remote.pushedIds, ['o1', 'o2']);
      expect(service.isRunning, isFalse);
    });

    test('apaga os concluídos com mais de 7 dias', () async {
      final old = await enqueueOrder('o1');
      await db.outboxDao.markDone(
        old,
        at: now.subtract(const Duration(days: 8)),
      );
      final recent = await enqueueOrder('o2');

      await service.sync();

      expect(await db.outboxDao.findById(old), isNull);
      expect((await entry(recent)).status, OutboxStatus.done);
    });

    test('o payload chega ao servidor em snake_case', () async {
      await db.outboxDao.enqueue(
        operation: OutboxOperation.update,
        entity: OutboxEntity.equipment,
        entityId: 'e1',
        userId: 'u1',
        payload: {'serialNumber': 'ABC', 'syncedAt': 'local'},
      );

      await service.sync();

      final op = remote.pushed.single;
      expect(op.table, 'equipment');
      expect(op.data, {'serial_number': 'ABC', 'id': 'e1'});
      expect(jsonEncode(op.data), isNot(contains('synced')));
    });
  });

  group('gatilhos automáticos', () {
    // Até 5 s: só espera o necessário, e o CI com cobertura é mais lento.
    Future<void> waitUntil(bool Function() condition) async {
      for (var i = 0; i < 1000 && !condition(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(condition(), isTrue);
    }

    test('envia ao ligar, a cada item novo e quando a sessão chega', () async {
      await enqueueOrder('o1');
      service.start();
      service.start(); // ligar duas vezes não duplica os gatilhos
      await waitUntil(() => remote.pushed.length == 1);

      await enqueueOrder('o2');
      await waitUntil(() => remote.pushed.length == 2);

      remote.session = false;
      await enqueueOrder('o3');
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(remote.pushed, hasLength(2));

      remote.session = true;
      remote.sessionController.add(null);
      await waitUntil(() => remote.pushed.length == 3);
      expect(remote.pushedIds, ['o1', 'o2', 'o3']);
    });

    test('tenta de novo sozinho quando chega a hora', () async {
      service = buildService(
        retryPolicy: const RetryPolicy(
          maxAttempts: 3,
          baseDelay: Duration.zero,
        ),
      );
      final a = await enqueueOrder('o1');
      remote.onPush = (_) => throw const SyncServerException('recusado');

      service.start();
      await waitUntil(() => remote.pushed.length == 3);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(remote.pushed, hasLength(3));
      expect((await entry(a)).attempts, 3);
    });

    test('sync manual também agenda a próxima tentativa', () async {
      service = buildService(
        retryPolicy: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration.zero,
        ),
      );
      await enqueueOrder('o1');
      remote.session = false;
      service.start();
      await pumpEventQueue();
      expect(remote.pushed, isEmpty);

      // Como o "Sincronizar agora" (B16) ou a reconexão (B21) fariam.
      remote.session = true;
      remote.onPush = (_) => throw const SyncServerException('recusado');
      await service.sync();

      await waitUntil(() => remote.pushed.length == 2);
    });

    test('queda de rede não apaga a nova tentativa já agendada', () async {
      // Relógio real: o timer e a espera entre tentativas usam a mesma hora.
      service = SyncService(
        outbox: db.outboxDao,
        remote: remote,
        retryPolicy: const RetryPolicy(
          baseDelay: Duration(seconds: 1),
        ),
      );
      var o1Fails = true;
      remote.onPush = (op) {
        if (op.id == 'o1' && o1Fails) {
          throw const SyncServerException('recusado');
        }
        if (op.id == 'o2') throw const SyncNetworkException('caiu');
      };
      await enqueueOrder('o1');

      service.start();
      await waitUntil(() => remote.pushed.length == 1 && !service.isRunning);

      // Rodada que cai por rede antes de o1 voltar a ser tentado.
      o1Fails = false;
      await enqueueOrder('o2');
      await waitUntil(() => remote.pushedIds.contains('o2'));

      await waitUntil(
        () => remote.pushedIds.where((id) => id == 'o1').length == 2,
      );
    });

    test('dispose desliga os gatilhos', () async {
      service.start();
      await pumpEventQueue();
      await service.dispose();

      await enqueueOrder('o1');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(remote.pushed, isEmpty);
    });
  });
}
