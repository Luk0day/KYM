/// Loja como a tela de lojas a enxerga: dados básicos e quantas ordens ainda
/// estão em aberto (aberta, agendada ou em andamento).
class StoreSummary {
  const StoreSummary({
    required this.id,
    required this.name,
    this.code,
    this.city,
    this.isActive = true,
    this.openOrders = 0,
  });

  final String id;
  final String name;
  final String? code;
  final String? city;
  final bool isActive;
  final int openOrders;
}
