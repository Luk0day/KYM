import 'dart:async';

import 'package:kym/app/sync/infra/remote_sync_datasource.dart';

/// Servidor de mentira: aplica as operações num mapa por tabela/id, do jeito
/// que o Supabase faria (inserção idempotente), e deixa o teste programar
/// falhas por operação.
class FakeRemoteSyncDataSource implements RemoteSyncDataSource {
  bool session = true;

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
  Future<bool> hasSession() async => session;

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
}
