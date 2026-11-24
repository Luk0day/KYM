import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../app/database/app_database.dart';
import '../../infra/datasources/store_local_datasource.dart';
import '../../infra/models/store_model.dart';

class DriftStoreLocalDataSource implements StoreLocalDataSource {
  DriftStoreLocalDataSource(this._db)
    : _clock = DateTime.now,
      _dayCheckEvery = defaultDayCheckEvery;

  /// Para testes: fixa o relógio usado para saber que dia é hoje e o
  /// intervalo em que a virada do dia é conferida.
  DriftStoreLocalDataSource.withClock(
    this._db,
    this._clock, {
    Duration? dayCheckEvery,
  }) : _dayCheckEvery = dayCheckEvery ?? defaultDayCheckEvery;

  /// De quanto em quanto tempo confere se o dia virou. Um timer até a
  /// meia-noite atrasaria com o aparelho dormindo ou com o relógio ajustado.
  static const Duration defaultDayCheckEvery = Duration(minutes: 1);

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Duration _dayCheckEvery;

  static const List<OrderStatus> _openStatuses = [
    OrderStatus.aberta,
    OrderStatus.agendada,
    OrderStatus.emAndamento,
  ];

  /// O Drift só reemite quando as tabelas mudam, mas uma ordem também fica
  /// atrasada quando o dia vira. Por isso a consulta é refeita quando a data
  /// de hoje muda, e só nesse momento.
  @override
  Stream<List<StoreModel>> watchStores() {
    late final StreamController<List<StoreModel>> controller;
    StreamSubscription<List<StoreModel>>? query;
    Timer? timer;
    DateTime? queriedDay;

    void listenQuery() {
      final today = _dateOnly(_clock());
      if (today == queriedDay) {
        return;
      }
      queriedDay = today;
      query?.cancel();
      query = _watchFrom(today)
          .listen(controller.add, onError: controller.addError);
    }

    controller = StreamController<List<StoreModel>>(
      onListen: () {
        listenQuery();
        timer = Timer.periodic(_dayCheckEvery, (_) => listenQuery());
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

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Uma consulta só: lojas com as contagens de ordens por situação. A ordem
  /// pendente fica atrasada quando a data agendada é anterior a [today], a
  /// mesma regra do `situationOn` das ordens. A ordem alfabética fica com a
  /// domain, que ignora acentos.
  Stream<List<StoreModel>> _watchFrom(DateTime today) {
    final stores = _db.stores;
    final orders = _db.maintenanceOrders;
    final isOpen = orders.status.isInValues(_openStatuses);

    final open = orders.id.count(filter: isOpen);
    final overdue = orders.id.count(
      filter: isOpen & orders.scheduledFor.isSmallerThanValue(today),
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
