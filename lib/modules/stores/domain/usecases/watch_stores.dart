import '../entities/store_filter.dart';
import '../entities/store_list_result.dart';
import '../entities/store_summary.dart';
import '../repositories/store_list_repository.dart';
import '../utils/text_normalizer.dart';

class WatchStores {
  WatchStores(this._repository);

  final StoreListRepository _repository;

  /// Lojas inativas só aparecem quando [includeInactive] é verdadeiro
  /// (gestor). A busca ignora maiúsculas e acentos e olha nome, código,
  /// cidade e endereço.
  Stream<StoreListResult> call({
    StoreFilter filter = const StoreFilter(),
    bool includeInactive = false,
  }) {
    final query = TextNormalizer.normalize(filter.query);

    return _repository.watchStores().map((stores) {
      final visible =
          stores.where((store) => includeInactive || store.isActive).toList()
            ..sort(_byName);

      final items = visible
          .where((store) => _matches(store, query, filter.kind))
          .toList();

      return StoreListResult(items: items, totalVisible: visible.length);
    });
  }

  static int _byName(StoreSummary a, StoreSummary b) {
    final byName = TextNormalizer.normalize(a.name)
        .compareTo(TextNormalizer.normalize(b.name));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  static bool _matches(StoreSummary store, String query, StoreFilterKind kind) {
    final matchesKind = switch (kind) {
      StoreFilterKind.todas => true,
      StoreFilterKind.comAtrasadas => store.overdueOrders > 0,
      StoreFilterKind.preventivas => store.preventiveOrders > 0,
      StoreFilterKind.corretivas => store.correctiveOrders > 0,
    };
    if (!matchesKind) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    return [store.name, store.code, store.city, store.address].any(
      (field) =>
          field != null && TextNormalizer.normalize(field).contains(query),
    );
  }
}
