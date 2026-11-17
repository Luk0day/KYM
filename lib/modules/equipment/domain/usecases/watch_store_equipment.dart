import '../../../../shared/domain/combine_latest.dart';
import '../../../orders/domain/entities/maintenance_order.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../entities/equipment.dart';
import '../entities/equipment_list_item.dart';
import '../repositories/equipment_repository.dart';

/// Equipamentos de uma loja com a contagem de ordens abertas e atrasadas.
/// Atrasados primeiro, depois por nome.
class WatchStoreEquipment {
  WatchStoreEquipment(
    this._equipment,
    this._orders, {
    this._clock = DateTime.now,
  });

  final EquipmentRepository _equipment;
  final OrderRepository _orders;
  final DateTime Function() _clock;

  Stream<List<EquipmentListItem>> call(String storeId) => combineLatest2(
    _equipment.watchByStore(storeId),
    _orders.watchByStore(storeId),
    _build,
  );

  List<EquipmentListItem> _build(
    List<Equipment> equipment,
    List<MaintenanceOrder> orders,
  ) {
    final now = _clock();
    final open = <String, int>{};
    final overdue = <String, int>{};

    for (final order in orders) {
      if (!_isOpen(order.status)) continue;
      open.update(order.equipmentId, (n) => n + 1, ifAbsent: () => 1);
      final due = order.scheduledFor;
      if (due != null && due.isBefore(now)) {
        overdue.update(order.equipmentId, (n) => n + 1, ifAbsent: () => 1);
      }
    }

    final items = [
      for (final e in equipment)
        EquipmentListItem(
          equipment: e,
          openOrders: open[e.id] ?? 0,
          overdueOrders: overdue[e.id] ?? 0,
        ),
    ]..sort(_compare);
    return items;
  }

  static bool _isOpen(OrderStatus status) =>
      status == OrderStatus.aberta ||
      status == OrderStatus.agendada ||
      status == OrderStatus.emAndamento;

  static int _compare(EquipmentListItem a, EquipmentListItem b) {
    if (a.hasOverdueOrder != b.hasOverdueOrder) {
      return a.hasOverdueOrder ? -1 : 1;
    }
    final byName = a.equipment.name.toLowerCase().compareTo(
      b.equipment.name.toLowerCase(),
    );
    return byName != 0 ? byName : a.equipment.id.compareTo(b.equipment.id);
  }
}
