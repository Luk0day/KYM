/// Loja atendida. Dart puro: não expõe as classes geradas pelo Drift.
class Store {
  const Store({
    required this.id,
    required this.name,
    required this.qrToken,
    required this.active,
    required this.createdAt,
    this.code,
    this.address,
    this.city,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final String? code;
  final String? address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String qrToken;
  final bool active;
  final DateTime createdAt;

  bool get hasCoordinates => latitude != null && longitude != null;
}
