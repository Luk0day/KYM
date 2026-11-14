import 'package:drift/drift.dart' show Value;

import '../../../../app/database/app_database.dart' as local;
import '../../domain/entities/maintenance_order.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(
    this._db, {
    required this._idGenerator,
    this._clock = DateTime.now,
  });

  final local.AppDatabase _db;
  final String Function() _idGenerator;
  final DateTime Function() _clock;

  @override
  Stream<List<MaintenanceOrder>> watchAll() => _db.maintenanceOrdersDao
      .watchAll()
      .map((rows) => rows.map(_toEntity).toList());

  @override
  Stream<List<MaintenanceOrder>> watchByStore(String storeId) => _db
      .maintenanceOrdersDao
      .watchByStore(storeId)
      .map((rows) => rows.map(_toEntity).toList());

  @override
  Stream<List<MaintenanceOrder>> watchByEquipment(String equipmentId) => _db
      .maintenanceOrdersDao
      .watchByEquipment(equipmentId)
      .map((rows) => rows.map(_toEntity).toList());

  @override
  Stream<MaintenanceOrder?> watchById(String id) => _db.maintenanceOrdersDao
      .watchById(id)
      .map((row) => row == null ? null : _toEntity(row));

  @override
  Future<MaintenanceOrder?> findById(String id) async {
    final row = await _db.maintenanceOrdersDao.findById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<MaintenanceOrder> create(NewOrder order) async {
    final id = _idGenerator();
    final now = _clock();
    final type = _typeToLocal(order.type);
    final status = _statusToLocal(order.status);

    await _db.transaction<void>(() async {
      await _db.maintenanceOrdersDao.upsert(
        local.MaintenanceOrdersCompanion.insert(
          id: id,
          equipmentId: order.equipmentId,
          storeId: order.storeId,
          type: type,
          status: Value(status),
          description: Value(order.description),
          scheduledFor: Value(order.scheduledFor),
          openedBy: Value(order.openedBy),
          assignedTo: Value(order.assignedTo),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.outboxDao.enqueue(
        operation: local.OutboxOperation.insert,
        entity: local.OutboxEntity.maintenanceOrder,
        entityId: id,
        // Mesmos nomes de coluna do Postgres, como a sync (B19) espera.
        payload: {
          'id': id,
          'equipment_id': order.equipmentId,
          'store_id': order.storeId,
          'type': type.dbValue,
          'status': status.dbValue,
          if (order.description != null) 'description': order.description,
          if (order.scheduledFor != null)
            'scheduled_for': order.scheduledFor!.toUtc().toIso8601String(),
          if (order.openedBy != null) 'opened_by': order.openedBy,
          if (order.assignedTo != null) 'assigned_to': order.assignedTo,
          'created_at': now.toUtc().toIso8601String(),
        },
      );
    });

    return (await findById(id))!;
  }

  MaintenanceOrder _toEntity(local.MaintenanceOrder row) => MaintenanceOrder(
    id: row.id,
    equipmentId: row.equipmentId,
    storeId: row.storeId,
    type: _typeFromLocal(row.type),
    status: _statusFromLocal(row.status),
    description: row.description,
    notes: row.notes,
    scheduledFor: row.scheduledFor,
    openedBy: row.openedBy,
    assignedTo: row.assignedTo,
    startedAt: row.startedAt,
    completedAt: row.completedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

OrderType _typeFromLocal(local.OrderType type) => switch (type) {
  local.OrderType.preventiva => OrderType.preventiva,
  local.OrderType.corretiva => OrderType.corretiva,
};

local.OrderType _typeToLocal(OrderType type) => switch (type) {
  OrderType.preventiva => local.OrderType.preventiva,
  OrderType.corretiva => local.OrderType.corretiva,
};

OrderStatus _statusFromLocal(local.OrderStatus status) => switch (status) {
  local.OrderStatus.aberta => OrderStatus.aberta,
  local.OrderStatus.agendada => OrderStatus.agendada,
  local.OrderStatus.emAndamento => OrderStatus.emAndamento,
  local.OrderStatus.concluida => OrderStatus.concluida,
  local.OrderStatus.cancelada => OrderStatus.cancelada,
};

local.OrderStatus _statusToLocal(OrderStatus status) => switch (status) {
  OrderStatus.aberta => local.OrderStatus.aberta,
  OrderStatus.agendada => local.OrderStatus.agendada,
  OrderStatus.emAndamento => local.OrderStatus.emAndamento,
  OrderStatus.concluida => local.OrderStatus.concluida,
  OrderStatus.cancelada => local.OrderStatus.cancelada,
};
