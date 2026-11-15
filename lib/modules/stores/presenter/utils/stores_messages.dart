import '../../domain/services/sync_service.dart';

const String storesLoadErrorMessage = 'Não foi possível carregar as lojas.';

extension SyncFailureMessage on SyncFailureType {
  String get userMessage {
    switch (this) {
      case SyncFailureType.offline:
        return 'Sem conexão. Mostrando os dados salvos no aparelho.';
      case SyncFailureType.server:
        return 'O servidor não respondeu. Tente sincronizar de novo.';
      case SyncFailureType.unexpected:
        return 'Não foi possível sincronizar agora.';
    }
  }
}
