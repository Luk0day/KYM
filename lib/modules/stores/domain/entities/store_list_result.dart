import 'store_summary.dart';

/// Resultado da listagem já filtrado, com o que a tela precisa para decidir
/// entre lista, "nenhuma loja atribuída" e "nenhum resultado".
class StoreListResult {
  const StoreListResult({required this.items, required this.totalVisible});

  static const StoreListResult empty = StoreListResult(
    items: [],
    totalVisible: 0,
  );

  /// Lojas que passaram pela busca e pelo filtro, em ordem alfabética.
  final List<StoreSummary> items;

  /// Quantas lojas o perfil enxerga, antes da busca e do filtro.
  final int totalVisible;
}
