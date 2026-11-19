import '../../../../shared/domain/combine_latest.dart';
import '../../../orders/domain/entities/maintenance_order.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../entities/equipment.dart';
import '../entities/equipment_list_item.dart';
import '../repositories/equipment_repository.dart';

/// Equipamentos de uma loja com o resumo das ordens de cada um. Atrasados
/// primeiro, depois por nome.
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
    final byEquipment = <String, List<MaintenanceOrder>>{};
    for (final order in orders) {
      byEquipment.putIfAbsent(order.equipmentId, () => []).add(order);
    }

    final items = [
      for (final e in equipment)
        _summarize(e, byEquipment[e.id] ?? const [], now),
    ]..sort(_compare);
    return items;
  }

  EquipmentListItem _summarize(
    Equipment equipment,
    List<MaintenanceOrder> orders,
    DateTime now,
  ) {
    bool isOverdue(MaintenanceOrder o) =>
        o.scheduledFor != null && o.scheduledFor!.isBefore(now);

    final open = orders.where((o) => _isOpen(o.status)).toList()
      ..sort((a, b) {
        if (isOverdue(a) != isOverdue(b)) return isOverdue(a) ? -1 : 1;
        final da = a.scheduledFor, db = b.scheduledFor;
        if (da == null || db == null) {
          return da == db ? 0 : (da == null ? 1 : -1);
        }
        return da.compareTo(db);
      });

    DateTime? lastDone;
    for (final o in orders) {
      final done = o.completedAt;
      if (o.status == OrderStatus.concluida &&
          done != null &&
          (lastDone == null || done.isAfter(lastDone))) {
        lastDone = done;
      }
    }

    return EquipmentListItem(
      equipment: equipment,
      openOrders: open.length,
      overdueOrders: open.where(isOverdue).length,
      nextOrderType: open.isEmpty ? null : open.first.type,
      lastMaintenanceAt: lastDone,
    );
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
