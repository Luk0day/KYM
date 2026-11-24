import 'dart:async';

import 'package:kym/modules/equipment/domain/entities/equipment.dart';
import 'package:kym/modules/equipment/domain/entities/equipment_status.dart';
import 'package:kym/modules/equipment/domain/repositories/equipment_repository.dart';
import 'package:kym/modules/orders/domain/entities/agenda_item.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart';
import 'package:kym/modules/orders/domain/repositories/order_repository.dart';

class FakeEquipmentRepository implements EquipmentRepository {
  FakeEquipmentRepository([List<Equipment> items = const []]) : _items = items;

  List<Equipment> _items;
  final _changes = StreamController<void>.broadcast();

  /// Quando definido, todas as streams falham com ele.
  Object? error;

  void emit(List<Equipment> items) {
    _items = items;
    _changes.add(null);
  }

  /// Não usa async*: cancelar um async* parado em wait for só vale no
  /// próximo yield e travaria o teste.
  Stream<T> _watch<T>(T Function() read) {
    if (error != null) return Stream<T>.error(error!);
    late StreamController<T> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        sub = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  @override
  Stream<List<Equipment>> watchAll() => _watch(() => _items);

  @override
  Stream<List<Equipment>> watchByStore(String storeId) =>
      _watch(() => _items.where((e) => e.storeId == storeId).toList());

  @override
  Stream<Equipment?> watchById(String id) =>
      _watch(() => _items.where((e) => e.id == id).firstOrNull);

  @override
  Future<Equipment?> findById(String id) async =>
      _items.where((e) => e.id == id).firstOrNull;

  @override
  Future<Equipment?> findByQrToken(String qrToken) async =>
      _items.where((e) => e.qrToken == qrToken).firstOrNull;
}

class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository([this.items = const []]);

  final List<MaintenanceOrder> items;

  @override
  Stream<List<MaintenanceOrder>> watchAll() => Stream.value(items);

  @override
  Stream<List<MaintenanceOrder>> watchByStore(String storeId) =>
      Stream.value(items.where((o) => o.storeId == storeId).toList());

  @override
  Stream<List<MaintenanceOrder>> watchByEquipment(String equipmentId) =>
      Stream.value(items.where((o) => o.equipmentId == equipmentId).toList());

  @override
  Stream<MaintenanceOrder?> watchById(String id) =>
      Stream.value(items.where((o) => o.id == id).firstOrNull);

  @override
  Future<MaintenanceOrder?> findById(String id) async =>
      items.where((o) => o.id == id).firstOrNull;

  @override
  Stream<List<AgendaItem>> watchAgenda({String? assignedTo}) =>
      throw UnimplementedError('watchAgenda não é usado nestes testes');

  @override
  Future<MaintenanceOrder> create(NewOrder order) =>
      throw UnimplementedError('create não é usado nestes testes');
}

Equipment equipmentFixture({
  String id = 'e1',
  String storeId = 's1',
  String name = 'Freezer 01',
  EquipmentStatus status = EquipmentStatus.operando,
  String? category = 'Refrigeração',
}) => Equipment(
  id: id,
  storeId: storeId,
  name: name,
  qrToken: 'qr-$id',
  status: status,
  createdAt: DateTime(2026, 1, 1),
  category: category,
);

MaintenanceOrder orderFixture({
  String id = 'o1',
  String equipmentId = 'e1',
  String storeId = 's1',
  OrderType type = OrderType.preventiva,
  OrderStatus status = OrderStatus.aberta,
  DateTime? scheduledFor,
  DateTime? completedAt,
  String? assignedTo,
}) => MaintenanceOrder(
  id: id,
  equipmentId: equipmentId,
  storeId: storeId,
  type: type,
  status: status,
  scheduledFor: scheduledFor,
  completedAt: completedAt,
  assignedTo: assignedTo,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);
