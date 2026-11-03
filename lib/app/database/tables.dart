import 'package:drift/drift.dart';

import 'enums.dart';

// Tabelas espelho do schema B04 do Supabase (stores, equipment,
// maintenance_orders, photos) mais a outbox local.
//
// Decisões:
// - O id é o próprio uuid do servidor (texto). O Supabase aceita id enviado
//   pelo cliente, então registros criados offline já nascem com o id final e
//   nenhuma chave estrangeira ou payload da outbox precisa ser remapeado.
// - `syncedAt` é local: nulo = nunca confirmado pelo servidor.
// - O schema não tem exclusão lógica (stores usa `active`), então não há
//   `deletedAt`.
// - profiles não é espelhado: opened_by, assigned_to e created_by ficam como
//   uuid solto, sem chave estrangeira.

@DataClassName('Store')
class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable().unique()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get qrToken => text().unique()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Equipment')
@TableIndex(name: 'equipment_store_idx', columns: {#storeId})
class Equipments extends Table {
  @override
  String get tableName => 'equipment';

  TextColumn get id => text()();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  TextColumn get brand => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get serialNumber => text().nullable()();
  TextColumn get qrToken => text().unique()();
  TextColumn get status => text().withDefault(const Constant('operando'))();
  DateTimeColumn get installedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MaintenanceOrder')
@TableIndex(name: 'orders_store_status_idx', columns: {#storeId, #status})
@TableIndex(name: 'orders_equipment_idx', columns: {#equipmentId})
class MaintenanceOrders extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipments, #id, onDelete: KeyAction.cascade)();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => text().map(const OrderTypeConverter())();
  TextColumn get status => text()
      .map(const OrderStatusConverter())
      .clientDefault(() => OrderStatus.aberta.dbValue)();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get scheduledFor => dateTime().nullable()();
  TextColumn get openedBy => text().nullable()();
  TextColumn get assignedTo => text().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Photo')
@TableIndex(name: 'photos_order_idx', columns: {#orderId})
class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get orderId =>
      text().references(MaintenanceOrders, #id, onDelete: KeyAction.cascade)();

  /// Caminho final no Storage do Supabase (o cliente pode calculá-lo antes do
  /// envio, por exemplo `orders/<orderId>/<photoId>.jpg`).
  TextColumn get storagePath => text()();

  /// Arquivo no aparelho. O binário nunca vai para o banco.
  TextColumn get localPath => text().nullable()();
  TextColumn get kind => text()
      .map(const PhotoKindConverter())
      .clientDefault(() => PhotoKind.depois.dbValue)();
  DateTimeColumn get takenAt => dateTime().clientDefault(DateTime.now)();
  TextColumn get createdBy => text().nullable()();
  TextColumn get uploadStatus => textEnum<PhotoUploadStatus>()
      .clientDefault(() => PhotoUploadStatus.pending.name)();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('OutboxEntry')
class Outbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => textEnum<OutboxOperation>()();
  TextColumn get entity => textEnum<OutboxEntity>()();
  TextColumn get entityId => text()();

  /// JSON serializado com os dados da operação.
  TextColumn get payload => text()();
  TextColumn get status => textEnum<OutboxStatus>()
      .clientDefault(() => OutboxStatus.pending.name)();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
}
