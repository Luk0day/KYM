import '../../domain/services/store_sync_trigger.dart';

/// Provisório: não sincroniza nada e avisa isso, para a tela não mostrar
/// "Sincronizado". A B20 registra o serviço real no lugar.
class NoopStoreSyncTrigger implements StoreSyncTrigger {
  @override
  Future<bool> sync() async => false;
}
