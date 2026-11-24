import 'maintenance_order.dart';

class AgendaItem {
  const AgendaItem({
    required this.order,
    required this.equipmentName,
    required this.storeName,
  });

  final MaintenanceOrder order;
  final String equipmentName;
  final String storeName;
}
