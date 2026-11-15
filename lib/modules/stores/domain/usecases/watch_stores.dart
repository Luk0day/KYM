import '../entities/store_filter.dart';
import '../entities/store_list_result.dart';
import '../entities/store_summary.dart';
import '../repositories/store_list_repository.dart';
import '../utils/text_normalizer.dart';

class WatchStores {
  WatchStores(this._repository);

  final StoreListRepository _repository;

  /// Lojas inativas só aparecem quando [includeInactive] é verdadeiro
  /// (gestor). A busca ignora maiúsculas e acentos e olha nome, código e
  /// cidade.
  Stream<StoreListResult> call({
    StoreFilter filter = const StoreFilter(),
    bool includeInactive = false,
  }) {
    final query = TextNormalizer.normalize(filter.query);
    final city = filter.city == null
        ? null
        : TextNormalizer.normalize(filter.city!);

    return _repository.watchStores().map((stores) {
      final visible = stores
          .where((store) => includeInactive || store.isActive)
          .toList()
        ..sort(_byName);

      final items = visible
          .where((store) => _matches(store, query, city, filter))
          .toList();

      return StoreListResult(
        items: items,
        availableCities: _cities(visible),
        totalVisible: visible.length,
      );
    });
  }

  static int _byName(StoreSummary a, StoreSummary b) {
    final byName = TextNormalizer.normalize(a.name)
        .compareTo(TextNormalizer.normalize(b.name));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  static bool _matches(
    StoreSummary store,
    String query,
    String? city,
    StoreFilter filter,
  ) {
    if (filter.onlyWithPending && store.openOrders <= 0) {
      return false;
    }
    if (city != null && TextNormalizer.normalize(store.city ?? '') != city) {
      return false;
    }
    if (query.isEmpty) {
      return true;
    }
    return [store.name, store.code, store.city].any(
      (field) =>
          field != null && TextNormalizer.normalize(field).contains(query),
    );
  }

  static List<String> _cities(List<StoreSummary> stores) {
    final byKey = <String, String>{};
    for (final store in stores) {
      final city = store.city?.trim();
      if (city != null && city.isNotEmpty) {
        byKey.putIfAbsent(TextNormalizer.normalize(city), () => city);
      }
    }
    final keys = byKey.keys.toList()..sort();
    return [for (final key in keys) byKey[key]!];
  }
}
