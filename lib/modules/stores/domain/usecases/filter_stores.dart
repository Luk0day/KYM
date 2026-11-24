import '../entities/store_filter.dart';
import '../entities/store_list_result.dart';
import '../entities/store_summary.dart';
import '../utils/text_normalizer.dart';

/// Aplica a busca e a aba de filtro sobre as lojas visíveis, mantendo a ordem.
class FilterStores {
  const FilterStores();

  /// A busca ignora maiúsculas e acentos e olha nome, código, cidade e
  /// endereço.
  StoreListResult call(List<StoreSummary> stores, StoreFilter filter) {
    final query = TextNormalizer.normalize(filter.query);

    return StoreListResult(
      items: [
        for (final store in stores)
          if (_matches(store, query, filter.kind)) store,
      ],
      totalVisible: stores.length,
    );
  }

  static bool _matches(StoreSummary store, String query, StoreFilterKind kind) {
    final matchesKind = switch (kind) {
      StoreFilterKind.todas => true,
      StoreFilterKind.comAtrasadas => store.overdueOrders > 0,
      // Mesmo critério do selo "Em dia" do cartão: nada em aberto.
      StoreFilterKind.emDia => store.openOrders == 0,
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
