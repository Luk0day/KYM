import '../../domain/services/sync_service.dart';

/// Provisório: não sincroniza nada. A B20 registra o serviço real no lugar.
class NoopSyncService implements SyncService {
  @override
  Future<void> sync() async {}
}
