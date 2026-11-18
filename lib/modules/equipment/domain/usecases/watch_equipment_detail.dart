import '../../../../shared/domain/combine_latest.dart';
import '../../../orders/domain/entities/maintenance_order.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../stores/domain/entities/store.dart';
import '../../../stores/domain/repositories/store_repository.dart';
import '../entities/equipment.dart';
import '../entities/equipment_detail.dart';
import '../repositories/equipment_repository.dart';

/// Equipamento + loja + histórico, tudo do banco local. Emite `null` se o
/// equipamento não existe (id inválido ou acesso removido).
class WatchEquipmentDetail {
  WatchEquipmentDetail(this._equipment, this._stores, this._orders);

  final EquipmentRepository _equipment;
  final StoreRepository _stores;
  final OrderRepository _orders;

  Stream<EquipmentDetail?> call(String equipmentId) => combineLatest3(
    _equipment.watchById(equipmentId),
    _stores.watchAll(),
    _orders.watchByEquipment(equipmentId),
    _build,
  );

  EquipmentDetail? _build(
    Equipment? equipment,
    List<Store> stores,
    List<MaintenanceOrder> orders,
  ) {
    if (equipment == null) return null;
    final history = [...orders]
      ..sort(
        (a, b) =>
            EquipmentDetail.orderDate(b)
                .compareTo(EquipmentDetail.orderDate(a)),
      );
    return EquipmentDetail(
      equipment: equipment,
      store: stores.where((s) => s.id == equipment.storeId).firstOrNull,
      history: history,
    );
  }
}
