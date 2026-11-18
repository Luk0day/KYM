import 'package:drift/drift.dart';

import '../../../../app/database/app_database.dart';
import '../../infra/datasources/store_local_datasource.dart';
import '../../infra/models/store_model.dart';

class DriftStoreLocalDataSource implements StoreLocalDataSource {
  DriftStoreLocalDataSource(this._db) : _clock = DateTime.now;

  /// Para testes: fixa o "agora" usado para decidir o que está atrasado.
  DriftStoreLocalDataSource.withClock(this._db, this._clock);

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const List<OrderStatus> _openStatuses = [
    OrderStatus.aberta,
    OrderStatus.agendada,
    OrderStatus.emAndamento,
  ];

  /// Uma consulta só: lojas com as contagens de ordens por situação. O
  /// "atrasado" é calculado no momento em que a consulta é montada.
  @override
  Stream<List<StoreModel>> watchStores() {
    final stores = _db.stores;
    final orders = _db.maintenanceOrders;
    final isOpen = orders.status.isInValues(_openStatuses);

    final open = orders.id.count(filter: isOpen);
    final overdue = orders.id.count(
      filter: isOpen & orders.scheduledFor.isSmallerThanValue(_clock()),
    );
    final preventive = orders.id.count(
      filter: isOpen & orders.type.equalsValue(OrderType.preventiva),
    );
    final corrective = orders.id.count(
      filter: isOpen & orders.type.equalsValue(OrderType.corretiva),
    );

    final query =
        _db.select(stores).join([
            leftOuterJoin(orders, orders.storeId.equalsExp(stores.id)),
          ])
          ..addColumns([open, overdue, preventive, corrective])
          ..groupBy([stores.id])
          ..orderBy([OrderingTerm.asc(stores.name)]);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          _toModel(
            row.readTable(stores),
            open: row.read(open) ?? 0,
            overdue: row.read(overdue) ?? 0,
            preventive: row.read(preventive) ?? 0,
            corrective: row.read(corrective) ?? 0,
          ),
      ],
    );
  }

  StoreModel _toModel(
    Store store, {
    required int open,
    required int overdue,
    required int preventive,
    required int corrective,
  }) {
    return StoreModel(
      id: store.id,
      name: store.name,
      code: store.code,
      address: store.address,
      city: store.city,
      active: store.active,
      openOrders: open,
      overdueOrders: overdue,
      preventiveOrders: preventive,
      correctiveOrders: corrective,
    );
  }
}
