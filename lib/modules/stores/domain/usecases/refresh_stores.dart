import '../services/sync_service.dart';

class RefreshStores {
  RefreshStores(this._syncService);

  final SyncService _syncService;

  /// Dispara a sincronização. Lança [SyncFailure] se não der.
  Future<void> call() => _syncService.sync();
}
