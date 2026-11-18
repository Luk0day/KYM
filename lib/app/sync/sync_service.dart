import 'dart:async';

import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import '../database/daos/outbox_dao.dart';
import 'infra/outbox_mapper.dart';
import 'infra/remote_sync_datasource.dart';
import 'retry_policy.dart';
import 'sync_exception.dart';

/// Resumo de uma rodada de sincronização.
class SyncResult {
  const SyncResult({
    this.sent = 0,
    this.failed = 0,
    this.skipped = 0,
    this.interruptedBy,
    this.nextRetryAt,
  });

  /// Itens confirmados pelo servidor.
  final int sent;

  /// Itens que o servidor recusou nesta rodada.
  final int failed;

  /// Itens que ficaram para depois: esperando a vez de tentar de novo ou
  /// dependentes de um registro cujo envio falhou.
  final int skipped;

  /// Por que a rodada parou antes do fim (sem rede, sem sessão). Nulo se a
  /// fila foi percorrida inteira.
  final SyncNetworkException? interruptedBy;

  /// Quando há item falho a tentar de novo. Nulo se não há.
  final DateTime? nextRetryAt;

  bool get interrupted => interruptedBy != null;

  SyncResult operator +(SyncResult other) => SyncResult(
        sent: sent + other.sent,
        failed: failed + other.failed,
        skipped: other.skipped,
        interruptedBy: other.interruptedBy,
        nextRetryAt: other.nextRetryAt,
      );

  @override
  String toString() => 'SyncResult(sent: $sent, failed: $failed, '
      'skipped: $skipped, interrupted: $interrupted)';
}

/// Processador da outbox: envia ao Supabase, na ordem em que foram criadas,
/// as operações gravadas offline pelos repositórios.
///
/// Regras:
/// - Erro de rede interrompe a rodada sem gastar tentativa; o item volta ao
///   estado anterior e espera a próxima conexão.
/// - Erro do servidor marca o item como falho e a fila segue.
/// - Falhos são tentados de novo até [RetryPolicy.maxAttempts] vezes, com
///   espera crescente; depois só por ação manual (`OutboxDao.resetFailed`).
/// - Um item cujo registro (ou registro pai: loja, equipamento, ordem) tem
///   envio falho ou adiado é pulado, para não gerar erro de chave estrangeira
///   em cascata nem aplicar uma atualização antes da inserção.
/// - Itens concluídos há mais de [doneRetention] são apagados.
class SyncService {
  SyncService({
    required this._outbox,
    required this._remote,
    this._mapper = const OutboxMapper(),
    this._retryPolicy = const RetryPolicy(),
    this._clock = DateTime.now,
    this.doneRetention = const Duration(days: 7),
  });

  final OutboxDao _outbox;
  final RemoteSyncDataSource _remote;
  final OutboxMapper _mapper;
  final RetryPolicy _retryPolicy;
  final DateTime Function() _clock;
  final Duration doneRetention;

  Future<SyncResult>? _running;
  bool _rerunRequested = false;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _retryTimer;

  bool get isRunning => _running != null;

  /// Liga os gatilhos automáticos: sessão disponível (abrir o app já logado,
  /// login), novo item na fila e a hora de tentar de novo um item falho. O
  /// reconectar (B21) e o "Sincronizar agora" (B16) chamam [sync] direto.
  void start() {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(_remote.sessionReady.listen((_) => _trigger()))
      ..add(_outbox.watchLastId().skip(1).listen((_) => _trigger()));
    _trigger();
  }

  /// Desliga os gatilhos. Uma rodada em andamento termina normalmente.
  Future<void> dispose() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Processa a fila. Se já houver uma rodada em andamento, não começa outra:
  /// devolve a atual e pede mais uma volta ao fim dela, para pegar o que foi
  /// enfileirado no meio.
  Future<SyncResult> sync() async {
    final running = _running;
    if (running != null) {
      _rerunRequested = true;
      return running;
    }
    final future = _runUntilSettled();
    _running = future;
    try {
      return await future;
    } finally {
      _running = null;
    }
  }

  void _trigger() {
    unawaited(sync().then(_scheduleRetry, onError: (Object _) {}));
  }

  void _scheduleRetry(SyncResult result) {
    _retryTimer?.cancel();
    _retryTimer = null;
    final next = result.nextRetryAt;
    // Sem gatilhos ligados (uso manual, testes) ou sem rede: quem acorda a
    // fila é a reconexão.
    if (next == null || result.interrupted || _subscriptions.isEmpty) return;
    final wait = next.difference(_clock());
    _retryTimer = Timer(wait.isNegative ? Duration.zero : wait, _trigger);
  }

  Future<SyncResult> _runUntilSettled() async {
    var total = const SyncResult();
    do {
      _rerunRequested = false;
      total = total + await _runOnce();
    } while (_rerunRequested && !total.interrupted);
    return total;
  }

  Future<SyncResult> _runOnce() async {
    if (!await _remote.hasSession()) {
      return const SyncResult(
        interruptedBy: SyncNetworkException('sem sessão'),
      );
    }

    // Só uma rodada roda por vez, então o que está em `processing` agora é
    // sobra de um app fechado no meio do envio.
    await _outbox.resetProcessing();

    final maxAttempts = _retryPolicy.maxAttempts;
    final blocked = <String>{
      for (final entry in await _outbox.listExhausted(maxAttempts: maxAttempts))
        entry.entityId,
    };
    final items = await _outbox.listRetryable(maxAttempts: maxAttempts);

    var sent = 0;
    var failed = 0;
    var skipped = 0;
    DateTime? nextRetryAt;

    void noteRetry(OutboxEntry entry, {int extraAttempts = 0}) {
      final at = _retryPolicy.nextAttemptAt(
        entry.attempts + extraAttempts,
        entry.lastAttemptAt ?? _clock(),
      );
      if (at != null && (nextRetryAt == null || at.isBefore(nextRetryAt!))) {
        nextRetryAt = at;
      }
    }

    for (final entry in items) {
      final RemoteOperation operation;
      try {
        operation = _mapper.toRemote(entry);
      } on FormatException catch (e) {
        await _outbox.markFailed(entry.id, 'payload inválido: ${e.message}');
        failed++;
        blocked.add(entry.entityId);
        continue;
      }

      if (blocked.contains(entry.entityId) ||
          _mapper.referencedIds(operation).any(blocked.contains)) {
        skipped++;
        blocked.add(entry.entityId);
        if (entry.status == OutboxStatus.failed) noteRetry(entry);
        continue;
      }

      if (entry.status == OutboxStatus.failed &&
          !_retryPolicy.isDue(entry.attempts, entry.lastAttemptAt, _clock())) {
        skipped++;
        blocked.add(entry.entityId);
        noteRetry(entry);
        continue;
      }

      final startedAt = _clock();
      await _outbox.markProcessing(entry.id, at: startedAt);
      try {
        await _remote.push(operation);
      } on SyncNetworkException catch (e) {
        await _outbox.release(entry.id, entry.status);
        return SyncResult(
          sent: sent,
          failed: failed,
          skipped: skipped,
          interruptedBy: e,
          nextRetryAt: nextRetryAt,
        );
      } catch (e) {
        await _outbox.markFailed(entry.id, _describe(e));
        failed++;
        blocked.add(entry.entityId);
        if (entry.attempts + 1 < maxAttempts) {
          noteRetry(
            entry.copyWith(lastAttemptAt: Value(startedAt)),
            extraAttempts: 1,
          );
        }
        continue;
      }
      await _outbox.markDoneAndSynced(entry, _clock());
      sent++;
    }

    await _outbox.purgeDone(olderThan: _clock().subtract(doneRetention));

    return SyncResult(
      sent: sent,
      failed: failed,
      skipped: skipped,
      nextRetryAt: nextRetryAt,
    );
  }

  static String _describe(Object error) =>
      error is SyncException ? error.toString() : 'erro inesperado: $error';
}
