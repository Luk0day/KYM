import 'dart:convert';

import '../../database/app_database.dart';
import 'remote_sync_datasource.dart';

/// Traduz um item da outbox para a operação no servidor: tabela, tipo de
/// operação e payload com as colunas em `snake_case`.
class OutboxMapper {
  const OutboxMapper();

  /// Colunas que só existem no banco local e não podem ir ao servidor.
  static const _localOnlyColumns = {'synced_at', 'local_path', 'upload_status'};

  /// Colunas que apontam para outros registros. Um item que referencia um
  /// registro cujo envio falhou precisa esperar por ele.
  static const foreignKeyColumns = ['store_id', 'equipment_id', 'order_id'];

  /// Lança [FormatException] se o payload não for um objeto JSON.
  RemoteOperation toRemote(OutboxEntry entry) {
    final decoded = jsonDecode(entry.payload);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'payload da outbox não é um objeto JSON',
        entry.payload,
      );
    }

    final data = <String, Object?>{
      for (final MapEntry(:key, :value) in decoded.entries)
        if (!_localOnlyColumns.contains(toSnakeCase(key)))
          toSnakeCase(key): value,
    };
    // O id do item manda: o payload pode não trazê-lo (atualizações parciais).
    data['id'] = entry.entityId;

    return RemoteOperation(
      kind: switch (entry.operation) {
        OutboxOperation.insert => RemoteOperationKind.insert,
        OutboxOperation.update => RemoteOperationKind.update,
        OutboxOperation.delete => RemoteOperationKind.delete,
      },
      table: tableFor(entry.entity),
      id: entry.entityId,
      data: data,
    );
  }

  /// Ids de outros registros referenciados pela operação.
  Iterable<String> referencedIds(RemoteOperation operation) sync* {
    for (final column in foreignKeyColumns) {
      final value = operation.data[column];
      if (value is String) yield value;
    }
  }

  static String tableFor(OutboxEntity entity) => switch (entity) {
        OutboxEntity.store => 'stores',
        OutboxEntity.equipment => 'equipment',
        OutboxEntity.maintenanceOrder => 'maintenance_orders',
        OutboxEntity.photo => 'photos',
      };

  /// `storeId` → `store_id`. Nomes já em `snake_case` ficam como estão.
  static String toSnakeCase(String key) => key.replaceAllMapped(
        RegExp('(?<=[a-z0-9])[A-Z]'),
        (m) => '_${m[0]!.toLowerCase()}',
      ).toLowerCase();
}
