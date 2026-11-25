import '../services/store_sync_trigger.dart';

class RefreshStores {
  RefreshStores(this._sync);

  final StoreSyncTrigger _sync;

  /// Dispara a sincronização. Retorna `false` se não houve sincronização
  /// real. Lança [SyncFailure] se não der.
  Future<bool> call() => _sync.sync();
}
