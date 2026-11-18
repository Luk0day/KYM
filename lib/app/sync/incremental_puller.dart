import 'package:drift/drift.dart' show Table;

import '../database/app_database.dart';
import 'infra/outbox_mapper.dart';
import 'infra/pull_tables.dart';
import 'infra/remote_sync_datasource.dart';

/// Resumo de uma baixada.
class PullResult {
  const PullResult({this.written = 0, this.skipped = 0, this.deleted = 0});

  /// Linhas gravadas (novas ou atualizadas).
  final int written;

  /// Linhas não gravadas: com operação local pendente, inválidas ou órfãs.
  final int skipped;

  /// Linhas locais apagadas porque sumiram do servidor (só na reconciliação).
  final int deleted;

  PullResult operator +(PullResult other) => PullResult(
        written: written + other.written,
        skipped: skipped + other.skipped,
        deleted: deleted + other.deleted,
      );

  @override
  String toString() =>
      'PullResult(written: $written, skipped: $skipped, deleted: $deleted)';
}

/// Baixada incremental (B20): para cada tabela, na ordem das chaves
/// estrangeiras, busca as linhas com `updated_at` a partir da última marca e
/// grava no Drift. As telas observam o Drift e se atualizam sozinhas.
///
/// Regras:
/// - A marca é o maior `updated_at` recebido do servidor; o relógio do
///   aparelho não entra na conta. Ela só avança, página a página, então uma
///   baixada interrompida continua de onde parou.
/// - O pull incremental recomeça um pouco antes da marca ([overlap]), para
///   pegar linhas gravadas por transações que terminaram depois de outras mais
///   novas. Reprocessar linhas é inofensivo (upsert).
/// - Registros com operação local ainda não enviada não são sobrescritos (a
///   regra completa de conflitos fica na B22).
/// - Exclusões: o servidor não tem exclusão lógica, então o incremental não as
///   vê. A reconciliação completa (baixar tudo e apagar o que sumiu) roda no
///   primeiro pull de cada tabela, quando pedida ("Sincronizar agora", B16) e
///   a cada [fullPullInterval]. Ela também traz o que passou a ser visível sem
///   mudar de `updated_at` (por exemplo, técnico adicionado a uma loja).
class IncrementalPuller {
  IncrementalPuller({
    required this._db,
    required this._remote,
    this._mapper = const OutboxMapper(),
    this._clock = DateTime.now,
    List<PullTable<Table, dynamic>>? tables,
    this.pageSize = 500,
    this.overlap = const Duration(seconds: 30),
    this.fullPullInterval = const Duration(hours: 24),
  }) : tables = tables ?? pullTables;

  final AppDatabase _db;
  final RemoteSyncDataSource _remote;
  final OutboxMapper _mapper;
  final DateTime Function() _clock;
  final List<PullTable<Table, dynamic>> tables;
  final int pageSize;
  final Duration overlap;
  final Duration fullPullInterval;

  /// Baixa todas as tabelas. Com [full], faz a reconciliação completa em
  /// todas. Lança `SyncNetworkException` ou `SyncServerException`; o que já
  /// foi gravado e a marca até ali ficam.
  Future<PullResult> pull({bool full = false}) async {
    final pending = await _pending();
    var total = const PullResult();
    for (final table in tables) {
      total = total + await _pullTable(table, pending, forceFull: full);
    }
    return total;
  }

  Future<PullResult> _pullTable(
    PullTable<Table, dynamic> table,
    _Pending pending, {
    required bool forceFull,
  }) async {
    final now = _clock();
    final state = await _db.pullDao.stateFor(table.remote);
    final storedCursor = state?.cursor;
    final lastFull = state?.lastFullPullAt;
    final full = forceFull ||
        storedCursor == null ||
        lastFull == null ||
        now.difference(lastFull) >= fullPullInterval;

    var after = full
        ? null
        : PullCursor(updatedAt: _shift(storedCursor, -overlap));
    var newest = storedCursor;
    final seen = <String>{};
    var written = 0;
    var skipped = 0;

    while (true) {
      final rows = await _remote.fetchChanges(
        table.remote,
        after: after,
        limit: pageSize,
      );
      if (rows.isEmpty) break;

      final page = await table.write(
        _db,
        rows,
        protectedIds: pending.own,
        syncedAt: now,
      );
      written += page.written;
      skipped += page.skipped;
      seen.addAll(page.ids);

      final last = rows.last;
      final lastUpdatedAt = _normalize(last['updated_at']);
      final lastId = last['id'];
      if (lastUpdatedAt == null || lastId is! String) {
        throw FormatException(
          'linha de ${table.remote} sem updated_at ou id válido',
          last,
        );
      }
      if (newest == null || _isAfter(lastUpdatedAt, newest)) {
        newest = lastUpdatedAt;
        await _db.pullDao.saveCursor(table.remote, newest);
      }
      if (rows.length < pageSize) break;
      after = PullCursor(updatedAt: lastUpdatedAt, id: lastId);
    }

    var deleted = 0;
    if (full) {
      deleted = await _db.pullDao.deleteMissing(
        table.local(_db),
        {...seen, ...pending.keep},
      );
      await _db.pullDao.markFullPull(table.remote, now);
    }
    return PullResult(written: written, skipped: skipped, deleted: deleted);
  }

  /// Registros com operação na outbox ainda não enviada e os que eles
  /// precisam para continuar existindo.
  Future<_Pending> _pending() async {
    final own = <String>{};
    final parents = <String>{};
    for (final entry in await _db.outboxDao.listUnsent()) {
      own.add(entry.entityId);
      try {
        parents.addAll(_mapper.referencedIds(_mapper.toRemote(entry)));
      } on FormatException {
        // Payload inválido: protege só o próprio registro.
      }
    }
    final ancestors = await _db.pullDao.ancestorsOf({...own, ...parents});
    return _Pending(own: own, keep: {...own, ...parents, ...ancestors});
  }

  static String? _normalize(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return parsed?.toUtc().toIso8601String();
  }

  static bool _isAfter(String a, String b) =>
      DateTime.parse(a).isAfter(DateTime.parse(b));

  static String _shift(String timestamp, Duration by) =>
      DateTime.parse(timestamp).add(by).toUtc().toIso8601String();
}

class _Pending {
  const _Pending({required this.own, required this.keep});

  /// Registros com operação local não enviada: o pull não os sobrescreve
  /// (a regra completa de conflitos fica na B22).
  final Set<String> own;

  /// O que a reconciliação não apaga: [own] mais os registros pai e avós
  /// (apagar a loja levaria a ordem e a foto pendentes junto, pelo cascade).
  final Set<String> keep;
}
