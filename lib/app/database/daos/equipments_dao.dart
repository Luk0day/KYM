import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'equipments_dao.g.dart';

@DriftAccessor(tables: [Equipments])
class EquipmentsDao extends DatabaseAccessor<AppDatabase>
    with _$EquipmentsDaoMixin {
  EquipmentsDao(super.db);

  Future<void> upsert(Insertable<Equipment> equipment) =>
      into(equipments).insertOnConflictUpdate(equipment);

  Future<Equipment?> findById(String id) =>
      (select(equipments)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<Equipment?> findByQrToken(String qrToken) => (select(
    equipments,
  )..where((e) => e.qrToken.equals(qrToken))).getSingleOrNull();

  Future<List<Equipment>> listAll() =>
      (select(equipments)..orderBy([(e) => OrderingTerm.asc(e.name)])).get();

  Stream<List<Equipment>> watchAll() =>
      (select(equipments)..orderBy([(e) => OrderingTerm.asc(e.name)])).watch();

  Stream<List<Equipment>> watchByStore(String storeId) =>
      (select(equipments)
            ..where((e) => e.storeId.equals(storeId))
            ..orderBy([(e) => OrderingTerm.asc(e.name)]))
          .watch();

  Stream<Equipment?> watchById(String id) =>
      (select(equipments)..where((e) => e.id.equals(id))).watchSingleOrNull();

  Future<List<Equipment>> listByStore(String storeId) =>
      (select(equipments)
            ..where((e) => e.storeId.equals(storeId))
            ..orderBy([(e) => OrderingTerm.asc(e.name)]))
          .get();
}
