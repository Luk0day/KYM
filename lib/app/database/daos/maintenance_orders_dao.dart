import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'maintenance_orders_dao.g.dart';

typedef AgendaRow = ({
  MaintenanceOrder order,
  Equipment equipment,
  Store store,
});

@DriftAccessor(tables: [MaintenanceOrders, Equipments, Stores])
class MaintenanceOrdersDao extends DatabaseAccessor<AppDatabase>
    with _$MaintenanceOrdersDaoMixin {
  MaintenanceOrdersDao(super.db);

  Future<void> upsert(Insertable<MaintenanceOrder> order) =>
      into(maintenanceOrders).insertOnConflictUpdate(order);

  Future<MaintenanceOrder?> findById(String id) => (select(
    maintenanceOrders,
  )..where((o) => o.id.equals(id))).getSingleOrNull();

  Future<List<MaintenanceOrder>> listAll() => (select(
    maintenanceOrders,
  )..orderBy([(o) => OrderingTerm.desc(o.createdAt)])).get();

  Stream<List<MaintenanceOrder>> watchAll() => (select(
    maintenanceOrders,
  )..orderBy([(o) => OrderingTerm.desc(o.createdAt)])).watch();

  Stream<MaintenanceOrder?> watchById(String id) => (select(
    maintenanceOrders,
  )..where((o) => o.id.equals(id))).watchSingleOrNull();

  Stream<List<MaintenanceOrder>> watchByStore(String storeId) =>
      (select(maintenanceOrders)
            ..where((o) => o.storeId.equals(storeId))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .watch();

  Stream<List<MaintenanceOrder>> watchByEquipment(String equipmentId) =>
      (select(maintenanceOrders)
            ..where((o) => o.equipmentId.equals(equipmentId))
            ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
          .watch();

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

  /// Ordens com o equipamento e a loja, para a agenda. Sem as canceladas e,
  /// quando [assignedTo] vier preenchido, só as atribuídas a essa pessoa.
  /// O innerJoin não perde ordens porque as chaves estrangeiras estão ligadas:
  /// a sincronização (B20) precisa gravar lojas e equipamentos antes das ordens.
  Stream<List<AgendaRow>> watchAgenda({String? assignedTo}) {
    final query =
        select(maintenanceOrders).join([
            innerJoin(
              equipments,
              equipments.id.equalsExp(maintenanceOrders.equipmentId),
            ),
            innerJoin(stores, stores.id.equalsExp(maintenanceOrders.storeId)),
          ])
          ..where(
            maintenanceOrders.status.equalsValue(OrderStatus.cancelada).not(),
          )
          ..orderBy([
            OrderingTerm.asc(maintenanceOrders.scheduledFor),
            OrderingTerm.asc(equipments.name),
          ]);

    if (assignedTo != null) {
      query.where(maintenanceOrders.assignedTo.equals(assignedTo));
    }

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          (
            order: row.readTable(maintenanceOrders),
            equipment: row.readTable(equipments),
            store: row.readTable(stores),
          ),
      ],
    );
  }
}
