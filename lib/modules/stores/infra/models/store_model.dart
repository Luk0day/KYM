class StoreModel {
  const StoreModel({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.city,
    this.active = true,
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
  final bool active;
  final int openOrders;
  final int overdueOrders;
  final int preventiveOrders;
  final int correctiveOrders;
}
