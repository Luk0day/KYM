import 'store_summary.dart';

/// Resultado da listagem já filtrado, com o que a tela precisa para decidir
/// entre lista, "nenhuma loja atribuída" e "nenhum resultado".
class StoreListResult {
  const StoreListResult({
    required this.items,
    required this.availableCities,
    required this.totalVisible,
  });

  static const StoreListResult empty = StoreListResult(
    items: [],
    availableCities: [],
    totalVisible: 0,
  );

  /// Lojas que passaram pela busca e pelos filtros, em ordem alfabética.
  final List<StoreSummary> items;

  /// Cidades das lojas visíveis ao perfil, para o filtro.
  final List<String> availableCities;

  /// Quantas lojas o perfil enxerga, antes da busca e dos filtros.
  final int totalVisible;
}
