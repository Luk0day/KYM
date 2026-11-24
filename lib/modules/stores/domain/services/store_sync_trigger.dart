enum SyncFailureType { offline, server, unexpected }

class SyncFailure implements Exception {
  const SyncFailure(this.type);

  final SyncFailureType type;

  @override
  String toString() => 'SyncFailure: ${type.name}';
}

/// O que a tela Lojas precisa da sincronização (implementado na B20, que
/// liga este contrato ao `SyncService` do app).
abstract interface class StoreSyncTrigger {
  /// Sincroniza e retorna `true`. Retorna `false` quando ainda não existe
  /// sincronização real, e então a tela não afirma que os dados estão em dia.
  /// Lança [SyncFailure] se não der.
  Future<bool> sync();
}
