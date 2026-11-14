import 'package:drift/drift.dart';

/// Enums do schema do Supabase (order_type, order_status, photo_kind).
/// Cada valor guarda o texto exato usado no servidor em [dbValue], para o
/// espelho local e o payload da outbox falarem o mesmo idioma do Postgres.

enum OrderType {
  preventiva('preventiva'),
  corretiva('corretiva');

  const OrderType(this.dbValue);
  final String dbValue;
}

enum OrderStatus {
  aberta('aberta'),
  agendada('agendada'),
  emAndamento('em_andamento'),
  concluida('concluida'),
  cancelada('cancelada');

  const OrderStatus(this.dbValue);
  final String dbValue;
}

enum PhotoKind {
  chamado('chamado'),
  antes('antes'),
  depois('depois');

  const PhotoKind(this.dbValue);
  final String dbValue;
}

/// Estado local do envio da foto (não existe no Supabase).
enum PhotoUploadStatus { pending, uploading, uploaded, failed }

/// Operação registrada na outbox.
enum OutboxOperation { insert, update, delete }

/// Entidade a que a operação da outbox se refere.
enum OutboxEntity { store, equipment, maintenanceOrder, photo }

/// Estado do item na fila.
enum OutboxStatus { pending, processing, failed, done }

class OrderTypeConverter extends TypeConverter<OrderType, String> {
  const OrderTypeConverter();

  @override
  OrderType fromSql(String fromDb) =>
      OrderType.values.firstWhere((e) => e.dbValue == fromDb);

  @override
  String toSql(OrderType value) => value.dbValue;
}

class OrderStatusConverter extends TypeConverter<OrderStatus, String> {
  const OrderStatusConverter();

  @override
  OrderStatus fromSql(String fromDb) =>
      OrderStatus.values.firstWhere((e) => e.dbValue == fromDb);

  @override
  String toSql(OrderStatus value) => value.dbValue;
}

class PhotoKindConverter extends TypeConverter<PhotoKind, String> {
  const PhotoKindConverter();

  @override
  PhotoKind fromSql(String fromDb) =>
      PhotoKind.values.firstWhere((e) => e.dbValue == fromDb);

  @override
  String toSql(PhotoKind value) => value.dbValue;
}
