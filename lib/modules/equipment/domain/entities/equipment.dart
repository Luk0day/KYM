/// Equipamento de uma loja. Dart puro.
class Equipment {
  const Equipment({
    required this.id,
    required this.storeId,
    required this.name,
    required this.qrToken,
    required this.status,
    required this.createdAt,
    this.category,
    this.brand,
    this.model,
    this.serialNumber,
    this.installedAt,
    this.notes,
  });

  final String id;
  final String storeId;
  final String name;
  final String? category;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final String qrToken;

  /// Texto do banco (`operando`...). A B27 troca por um enum.
  final String status;
  final DateTime? installedAt;
  final String? notes;
  final DateTime createdAt;
}
