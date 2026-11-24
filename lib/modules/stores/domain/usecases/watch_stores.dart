import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/domain/entities/user_role_permissions.dart';
import '../entities/store_summary.dart';
import '../repositories/store_list_repository.dart';
import '../utils/text_normalizer.dart';

/// Lojas que o perfil enxerga, em ordem alfabética. A busca e as abas de filtro
/// ficam no `FilterStores`, em memória, para não refazer a consulta ao banco a
/// cada tecla.
class WatchStores {
  WatchStores(this._repository);

  final StoreListRepository _repository;

  /// Lojas inativas só aparecem para quem pode vê-las (gestor). Sem perfil,
  /// ficam escondidas. A ordem ignora maiúsculas e acentos.
  Stream<List<StoreSummary>> call({required UserRole? role}) {
    final includeInactive = role?.canViewInactiveStores ?? false;

    return _repository.watchStores().map(
      (stores) =>
          stores.where((store) => includeInactive || store.isActive).toList()
            ..sort(_byName),
    );
  }

  static int _byName(StoreSummary a, StoreSummary b) {
    final byName = TextNormalizer.normalize(a.name)
        .compareTo(TextNormalizer.normalize(b.name));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }
}
