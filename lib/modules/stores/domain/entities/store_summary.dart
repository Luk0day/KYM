/// Loja como a tela de lojas a enxerga: dados básicos e a situação das ordens
/// de manutenção em aberto (aberta, agendada ou em andamento).
class StoreSummary {
  const StoreSummary({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.city,
    this.isActive = true,
    this.openOrders = 0,
    this.overdueOrders = 0,
    this.preventiveOrders = 0,
    this.correctiveOrders = 0,
  });

  final String id;
  final String name;
  final String? code;
  final String? address;
  final String? city;
  final bool isActive;

  /// Ordens em aberto, de qualquer tipo.
  final int openOrders;

  /// Ordens em aberto cuja data agendada já passou.
  final int overdueOrders;

  /// Ordens em aberto de cada tipo.
  final int preventiveOrders;
  final int correctiveOrders;
}
