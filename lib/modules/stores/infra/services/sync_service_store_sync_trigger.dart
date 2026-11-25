import '../../../../app/sync/sync_service.dart';
import '../../domain/services/store_sync_trigger.dart';

/// Liga o "puxar para atualizar" da tela Lojas ao `SyncService` (B19/B20):
/// envia a outbox e baixa as novidades do servidor.
///
/// Pede a reconciliação completa, que também tira do aparelho as lojas que o
/// usuário deixou de ver (por exemplo, técnico retirado de uma loja). É uma
/// ação do usuário, então vale baixar tudo.
///
/// Só a baixada decide o resultado: é ela que deixa a lista em dia. Itens da
/// outbox recusados pelo servidor aparecem no indicador de sync (B21).
class SyncServiceStoreSyncTrigger implements StoreSyncTrigger {
  SyncServiceStoreSyncTrigger(this._service);

  final SyncService _service;

  @override
  Future<bool> sync() async {
    final result = await _service.sync(fullPull: true);
    if (result.interrupted) {
      throw const SyncFailure(SyncFailureType.offline);
    }
    if (result.pullError != null) {
      throw const SyncFailure(SyncFailureType.server);
    }
    // Sem baixada (serviço sem puller), a lista não foi conferida com o
    // servidor.
    return result.pulled != null;
  }
}
