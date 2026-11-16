import '../../domain/entities/store_filter.dart';
import '../../domain/services/sync_service.dart';
import '../controllers/stores_controller.dart';

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

extension SyncIndicatorLabel on SyncIndicator {
  String get label {
    switch (this) {
      case SyncIndicator.synced:
        return 'Sincronizado';
      case SyncIndicator.offline:
        return 'Offline';
      case SyncIndicator.failed:
        return 'Falha ao sincronizar';
    }
  }
}

extension StoreFilterKindLabel on StoreFilterKind {
  String get label {
    switch (this) {
      case StoreFilterKind.todas:
        return 'Todas';
      case StoreFilterKind.comAtrasadas:
        return 'Com atrasadas';
      case StoreFilterKind.preventivas:
        return 'Preventivas';
      case StoreFilterKind.corretivas:
        return 'Corretivas';
    }
  }
}

String storeCountLabel(int count) => count == 1 ? '1 loja' : '$count lojas';
