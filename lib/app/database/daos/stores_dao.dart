import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'stores_dao.g.dart';

@DriftAccessor(tables: [Stores])
class StoresDao extends DatabaseAccessor<AppDatabase> with _$StoresDaoMixin {
  StoresDao(super.db);

  Future<void> upsert(Insertable<Store> store) =>
      into(stores).insertOnConflictUpdate(store);

  Future<Store?> findById(String id) =>
      (select(stores)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<Store?> findByQrToken(String qrToken) => (select(
    stores,
  )..where((s) => s.qrToken.equals(qrToken))).getSingleOrNull();

  Future<List<Store>> listAll() =>
      (select(stores)..orderBy([(s) => OrderingTerm.asc(s.name)])).get();

  Stream<List<Store>> watchAll() =>
      (select(stores)..orderBy([(s) => OrderingTerm.asc(s.name)])).watch();

  Stream<Store?> watchById(String id) =>
      (select(stores)..where((s) => s.id.equals(id))).watchSingleOrNull();
}
