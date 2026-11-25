import 'dart:async';
import 'dart:developer' as developer;

import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import '../database/daos/outbox_dao.dart';
import 'incremental_puller.dart';
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
    this.pulled,
    this.pullError,
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

  /// Resumo da baixada (B20). Nulo se ela não rodou: sem puller, rodada
  /// interrompida no envio ou baixada interrompida pela rede.
  final PullResult? pulled;

  /// Erro do servidor que parou a baixada (a rede caindo vai em
  /// [interruptedBy]).
  final String? pullError;

  bool get interrupted => interruptedBy != null;

  SyncResult operator +(SyncResult other) => SyncResult(
        sent: sent + other.sent,
        failed: failed + other.failed,
        skipped: other.skipped,
        interruptedBy: other.interruptedBy,
        nextRetryAt: other.nextRetryAt,
        pulled: switch ((pulled, other.pulled)) {
          (final a?, final b?) => a + b,
          (final a, final b) => b ?? a,
        },
        pullError: other.pullError,
      );

  @override
  String toString() => 'SyncResult(sent: $sent, failed: $failed, '
      'skipped: $skipped, interrupted: $interrupted, pulled: $pulled'
      '${pullError == null ? '' : ', pullError: $pullError'})';
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
/// - Só vão os itens do usuário logado (o RLS exige que o dono os envie); os
///   de outro usuário esperam ele entrar de novo.
/// - Itens concluídos há mais de [doneRetention] são apagados.
/// - Depois do envio, faz a baixada (B20) com o [IncrementalPuller], se
///   houver. Enviar antes garante que o servidor já tem as alterações locais.
class SyncService {
  SyncService({
    required this._outbox,
    required this._remote,
    this._puller,
    this._mapper = const OutboxMapper(),
    this._retryPolicy = const RetryPolicy(),
    this._clock = DateTime.now,
    this.doneRetention = const Duration(days: 7),
  });

  final OutboxDao _outbox;
  final RemoteSyncDataSource _remote;
  final IncrementalPuller? _puller;
  final OutboxMapper _mapper;
  final RetryPolicy _retryPolicy;
  final DateTime Function() _clock;
  final Duration doneRetention;

  Future<SyncResult>? _running;
  bool _rerunRequested = false;
  bool _fullPullRequested = false;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _retryTimer;
  DateTime? _retryAt;

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
    _cancelRetry();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Envia a fila e baixa as novidades. Se já houver uma rodada em andamento,
  /// não começa outra: devolve a atual e pede mais uma volta ao fim dela, para
  /// pegar o que foi enfileirado no meio.
  ///
  /// [fullPull] pede a reconciliação completa da baixada, que também apaga o
  /// que sumiu do servidor ("Sincronizar agora", B16). Se a rodada for
  /// interrompida, o pedido fica para a próxima.
  Future<SyncResult> sync({bool fullPull = false}) async {
    if (fullPull) _fullPullRequested = true;
    final running = _running;
    if (running != null) {
      _rerunRequested = true;
      return running;
    }
    final SyncResult result;
    final future = _runUntilSettled();
    _running = future;
    try {
      result = await future;
    } finally {
      _running = null;
    }
    // Pedido que chegou depois da última volta, mas antes de a trava ser
    // liberada: atende agora para o item não ficar parado até o próximo
    // gatilho.
    if (_rerunRequested && !result.interrupted) {
      _rerunRequested = false;
      _trigger();
    }
    _scheduleRetry(result);
    return result;
  }

  void _trigger() {
    unawaited(
      sync().then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) => developer.log(
          'falha ao processar a outbox',
          name: 'kym.sync',
          error: error,
          stackTrace: stack,
        ),
      ),
    );
  }

  void _scheduleRetry(SyncResult result) {
    final next = result.nextRetryAt;
    if (!result.interrupted) {
      _cancelRetry();
    } else {
      // A rodada parou no meio (sem rede, sem sessão) e não viu a fila toda:
      // o agendamento que já existia continua valendo. Só é antecipado se a
      // rodada achou uma tentativa mais cedo.
      final current = _retryAt;
      if (current != null && (next == null || !next.isBefore(current))) {
        return;
      }
    }
    // Sem gatilhos ligados (testes, app sem sessão), quem acorda a fila é a
    // próxima chamada a [sync].
    if (next == null || _subscriptions.isEmpty) return;
    _cancelRetry();
    _retryAt = next;
    final wait = next.difference(_clock());
    _retryTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      _retryTimer = null;
      _retryAt = null;
      _trigger();
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAt = null;
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
    final userId = await _remote.currentUserId();
    if (userId == null) {
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

    // Item preso a outro (registro pai, item anterior do mesmo registro, dono
    // deslogado) não agenda nada: quem o destrava é o agendamento do outro.
    // Agendar um item preso e já vencido faria o timer disparar sem parar.
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
      // Item de outro usuário: o RLS exige que o dono esteja logado, então ele
      // espera o dono voltar e segura o que depende dele. Itens sem dono são
      // anteriores à v2 do banco e vão com quem estiver logado.
      if (entry.userId != null && entry.userId != userId) {
        skipped++;
        blocked.add(entry.entityId);
        continue;
      }

      if (blocked.contains(entry.entityId)) {
        skipped++;
        continue;
      }

      // Antes do mapeamento, para um payload inválido também esperar a vez.
      if (entry.status == OutboxStatus.failed &&
          !_retryPolicy.isDue(entry.attempts, entry.lastAttemptAt, _clock())) {
        skipped++;
        blocked.add(entry.entityId);
        noteRetry(entry);
        continue;
      }

      final RemoteOperation operation;
      try {
        operation = _mapper.toRemote(entry);
      } on FormatException catch (e) {
        await _outbox.markFailed(
          entry.id,
          'payload inválido: ${e.message}',
          at: _clock(),
        );
        failed++;
        blocked.add(entry.entityId);
        if (entry.attempts + 1 < maxAttempts) {
          noteRetry(
            entry.copyWith(lastAttemptAt: Value(_clock())),
            extraAttempts: 1,
          );
        }
        continue;
      }

      if (_mapper.referencedIds(operation).any(blocked.contains)) {
        skipped++;
        blocked.add(entry.entityId);
        continue;
      }

      final startedAt = _clock();
      await _outbox.markProcessing(entry.id);
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
        await _outbox.markFailed(entry.id, _describe(e), at: startedAt);
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

    final puller = _puller;
    PullResult? pulled;
    String? pullError;
    if (puller != null) {
      final full = _fullPullRequested;
      _fullPullRequested = false;
      try {
        pulled = await puller.pull(full: full, userId: userId);
      } on SyncNetworkException catch (e) {
        _fullPullRequested = _fullPullRequested || full;
        return SyncResult(
          sent: sent,
          failed: failed,
          skipped: skipped,
          interruptedBy: e,
          nextRetryAt: nextRetryAt,
        );
      } catch (e) {
        // Erro do servidor ou linha inválida: o que já foi gravado fica, e a
        // próxima rodada continua da marca salva.
        _fullPullRequested = _fullPullRequested || full;
        pullError = _describe(e);
      }
    }

    return SyncResult(
      sent: sent,
      failed: failed,
      skipped: skipped,
      nextRetryAt: nextRetryAt,
      pulled: pulled,
      pullError: pullError,
    );
  }

  static String _describe(Object error) =>
      error is SyncException ? error.toString() : 'erro inesperado: $error';
}
