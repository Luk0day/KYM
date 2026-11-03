import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'maintenance_orders_dao.g.dart';

@DriftAccessor(tables: [MaintenanceOrders])
class MaintenanceOrdersDao extends DatabaseAccessor<AppDatabase>
    with _$MaintenanceOrdersDaoMixin {
  MaintenanceOrdersDao(super.db);

  Future<void> upsert(Insertable<MaintenanceOrder> order) =>
      into(maintenanceOrders).insertOnConflictUpdate(order);

  Future<MaintenanceOrder?> findById(String id) => (select(maintenanceOrders)
        ..where((o) => o.id.equals(id)))
      .getSingleOrNull();

  Future<List<MaintenanceOrder>> listAll() => (select(maintenanceOrders)
        ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
      .get();

  Future<List<MaintenanceOrder>> listByStore(String storeId) =>
      (select(maintenanceOrders)
            ..where((o) => o.storeId.equals(storeId))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();

  Future<List<MaintenanceOrder>> listByEquipment(String equipmentId) =>
      (select(maintenanceOrders)
            ..where((o) => o.equipmentId.equals(equipmentId))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .get();
}
