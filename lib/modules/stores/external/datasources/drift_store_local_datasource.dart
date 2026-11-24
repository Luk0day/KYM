import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../app/database/app_database.dart';
import '../../infra/datasources/store_local_datasource.dart';
import '../../infra/models/store_model.dart';

class DriftStoreLocalDataSource implements StoreLocalDataSource {
  DriftStoreLocalDataSource(this._db)
    : _clock = DateTime.now,
      _recountEvery = defaultRecountEvery;

  /// Para testes: fixa o "agora" usado para decidir o que está atrasado e o
  /// intervalo da recontagem.
  DriftStoreLocalDataSource.withClock(
    this._db,
    this._clock, {
    Duration? recountEvery,
  }) : _recountEvery = recountEvery ?? defaultRecountEvery;

  /// De quanto em quanto tempo o "atrasado" é recalculado sem mudança no banco.
  static const Duration defaultRecountEvery = Duration(minutes: 1);

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Duration _recountEvery;

  static const List<OrderStatus> _openStatuses = [
    OrderStatus.aberta,
    OrderStatus.agendada,
    OrderStatus.emAndamento,
  ];

  /// O Drift só reemite quando as tabelas mudam, mas uma ordem também fica
  /// atrasada com a simples passagem do tempo. Por isso a consulta é refeita
  /// a cada [_recountEvery] com o "agora" atualizado.
  @override
  Stream<List<StoreModel>> watchStores() {
    late final StreamController<List<StoreModel>> controller;
    StreamSubscription<List<StoreModel>>? query;
    Timer? timer;

    void listenQuery() {
      query?.cancel();
      query = _watchAt(_clock())
          .listen(controller.add, onError: controller.addError);
    }

    controller = StreamController<List<StoreModel>>(
      onListen: () {
        listenQuery();
        timer = Timer.periodic(_recountEvery, (_) => listenQuery());
      },
      onPause: () => query?.pause(),
      onResume: () => query?.resume(),
      onCancel: () {
        timer?.cancel();
        return query?.cancel();
      },
    );
    return controller.stream;
  }

  /// Uma consulta só: lojas com as contagens de ordens por situação, com
  /// "atrasado" medido em relação a [now]. A ordem alfabética fica com a
  /// domain, que ignora acentos.
  Stream<List<StoreModel>> _watchAt(DateTime now) {
    final stores = _db.stores;
    final orders = _db.maintenanceOrders;
    final isOpen = orders.status.isInValues(_openStatuses);

    final open = orders.id.count(filter: isOpen);
    final overdue = orders.id.count(
      filter: isOpen & orders.scheduledFor.isSmallerThanValue(now),
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
          ..groupBy([stores.id]);

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
