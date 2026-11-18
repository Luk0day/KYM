enum SyncFailureType { offline, server, unexpected }

class SyncFailure implements Exception {
  const SyncFailure(this.type);

  final SyncFailureType type;

  @override
  String toString() => 'SyncFailure: ${type.name}';
}

/// Contrato da sincronização (implementado na B20). Lança [SyncFailure].
abstract interface class SyncService {
  Future<void> sync();
}
