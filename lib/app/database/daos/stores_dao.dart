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

  Future<List<Store>> listAll() =>
      (select(stores)..orderBy([(s) => OrderingTerm.asc(s.name)])).get();
}
