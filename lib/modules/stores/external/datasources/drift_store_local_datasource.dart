import 'package:drift/drift.dart';

import '../../../../app/database/app_database.dart';
import '../../infra/datasources/store_local_datasource.dart';
import '../../infra/models/store_model.dart';

class DriftStoreLocalDataSource implements StoreLocalDataSource {
  DriftStoreLocalDataSource(this._db);

  final AppDatabase _db;

  static const List<OrderStatus> _openStatuses = [
    OrderStatus.aberta,
    OrderStatus.agendada,
    OrderStatus.emAndamento,
  ];

  @override
  Stream<List<StoreModel>> watchStores() {
    final stores = _db.stores;
    final orders = _db.maintenanceOrders;
    final openOrders = orders.id.count(
      filter: orders.status.isInValues(_openStatuses),
    );

    final query = _db.select(stores).join([
      leftOuterJoin(orders, orders.storeId.equalsExp(stores.id)),
    ])
      ..addColumns([openOrders])
      ..groupBy([stores.id])
      ..orderBy([OrderingTerm.asc(stores.name)]);

    return query.watch().map(
          (rows) => [
            for (final row in rows)
              _toModel(row.readTable(stores), row.read(openOrders) ?? 0),
          ],
        );
  }

  StoreModel _toModel(Store store, int openOrders) {
    return StoreModel(
      id: store.id,
      name: store.name,
      code: store.code,
      city: store.city,
      active: store.active,
      openOrders: openOrders,
    );
  }
}
