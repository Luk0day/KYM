import 'dart:async';

import 'package:kym/app/sync/infra/remote_sync_datasource.dart';

/// Servidor de mentira: aplica as operações num mapa por tabela/id, do jeito
/// que o Supabase faria (inserção idempotente), e deixa o teste programar
/// falhas por operação.
class FakeRemoteSyncDataSource implements RemoteSyncDataSource {
  bool session = true;

  /// Usuário logado enquanto [session] for verdadeiro.
  String userId = 'u1';

  /// Chamado antes de aplicar cada operação; lançar aqui simula a falha.
  FutureOr<void> Function(RemoteOperation op)? onPush;

  /// Chamado depois de aplicar; lançar aqui simula a rede caindo depois de o
  /// servidor já ter gravado.
  FutureOr<void> Function(RemoteOperation op)? afterApply;

  final List<RemoteOperation> pushed = [];
  final Map<String, Map<String, Map<String, Object?>>> rows = {};
  final StreamController<void> sessionController =
      StreamController<void>.broadcast();

  @override
  Future<String?> currentUserId() async => session ? userId : null;

  @override
  Stream<void> get sessionReady => sessionController.stream;

  @override
  Future<void> push(RemoteOperation op) async {
    pushed.add(op);
    await onPush?.call(op);
    final table = rows.putIfAbsent(op.table, () => {});
    switch (op.kind) {
      case RemoteOperationKind.insert:
        table.putIfAbsent(op.id, () => Map.of(op.data));
      case RemoteOperationKind.update:
        table[op.id]?.addAll(op.data);
      case RemoteOperationKind.delete:
        table.remove(op.id);
    }
    await afterApply?.call(op);
  }

  List<String> get pushedIds => [for (final op in pushed) op.id];

  /// Chamado antes de cada página da baixada; lançar aqui simula a falha.
  FutureOr<void> Function(String table, PullCursor? after)? onFetch;

  /// Páginas pedidas, na ordem: (tabela, cursor).
  final List<(String, PullCursor?)> fetches = [];

  /// Grava uma linha "no servidor", como o painel do Supabase faria.
  void serverUpsert(String table, Map<String, Object?> row) =>
      rows.putIfAbsent(table, () => {})[row['id']! as String] = row;

  @override
  Future<List<Map<String, dynamic>>> fetchChanges(
    String table, {
    PullCursor? after,
    required int limit,
  }) async {
    fetches.add((table, after));
    await onFetch?.call(table, after);

    DateTime at(Map<String, Object?> r) =>
        DateTime.parse(r['updated_at']! as String);
    int compare(Map<String, Object?> a, Map<String, Object?> b) {
      final byTime = at(a).compareTo(at(b));
      return byTime != 0
          ? byTime
          : (a['id']! as String).compareTo(b['id']! as String);
    }

    final all = (rows[table]?.values ?? const <Map<String, Object?>>[])
        .where((r) => r['updated_at'] != null)
        .toList()
      ..sort(compare);

    // Mesma semântica do filtro do datasource real (gte ou keyset).
    bool isAfterCursor(Map<String, Object?> r) {
      if (after == null) return true;
      final cursorAt = DateTime.parse(after.updatedAt);
      final id = after.id;
      if (id == null) return !at(r).isBefore(cursorAt);
      return at(r).isAfter(cursorAt) ||
          (at(r).isAtSameMomentAs(cursorAt) &&
              (r['id']! as String).compareTo(id) > 0);
    }

    final page = [
      for (final r in all.where(isAfterCursor).take(limit))
        Map<String, dynamic>.of(r),
    ];
    return mapResult?.call(table, page) ?? page;
  }

  /// Troca a página devolvida, para simular linhas que o servidor real
  /// mandaria malformadas.
  List<Map<String, dynamic>> Function(
    String table,
    List<Map<String, dynamic>> rows,
  )? mapResult;
}
