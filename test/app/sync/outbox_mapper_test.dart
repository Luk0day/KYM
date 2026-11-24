import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/app/sync/infra/outbox_mapper.dart';
import 'package:kym/app/sync/infra/remote_sync_datasource.dart';
import 'package:kym/app/sync/retry_policy.dart';

OutboxEntry _entry({
  OutboxOperation operation = OutboxOperation.insert,
  OutboxEntity entity = OutboxEntity.maintenanceOrder,
  String entityId = 'o1',
  String payload = '{}',
}) =>
    OutboxEntry(
      id: 1,
      operation: operation,
      entity: entity,
      entityId: entityId,
      payload: payload,
      status: OutboxStatus.pending,
      attempts: 0,
      createdAt: DateTime(2026, 11, 18),
    );

void main() {
  const mapper = OutboxMapper();

  group('OutboxMapper', () {
    test('mapeia cada entidade para a tabela do Postgres', () {
      expect(OutboxMapper.tableFor(OutboxEntity.store), 'stores');
      expect(OutboxMapper.tableFor(OutboxEntity.equipment), 'equipment');
      expect(
        OutboxMapper.tableFor(OutboxEntity.maintenanceOrder),
        'maintenance_orders',
      );
      expect(OutboxMapper.tableFor(OutboxEntity.photo), 'photos');
    });

    test('mapeia cada operação', () {
      expect(
        [
          for (final op in OutboxOperation.values)
            mapper.toRemote(_entry(operation: op)).kind,
        ],
        [
          RemoteOperationKind.insert,
          RemoteOperationKind.update,
          RemoteOperationKind.delete,
        ],
      );
    });

    test('passa as chaves para snake_case, tira as locais e fixa o id', () {
      final op = mapper.toRemote(
        _entry(
          entity: OutboxEntity.photo,
          entityId: 'p1',
          payload: '{"id":"outro","orderId":"o1","storage_path":"a.jpg",'
              '"localPath":"/tmp/a.jpg","upload_status":"pending",'
              '"syncedAt":null}',
        ),
      );

      expect(op.table, 'photos');
      expect(op.id, 'p1');
      expect(op.data, {'id': 'p1', 'order_id': 'o1', 'storage_path': 'a.jpg'});
      expect(mapper.referencedIds(op), ['o1']);
      expect(op.toString(), 'RemoteOperation(insert photos/p1)');
    });

    test('payload que não é objeto lança FormatException', () {
      expect(
        () => mapper.toRemote(_entry(payload: '"texto"')),
        throwsFormatException,
      );
    });

    test('toSnakeCase', () {
      expect(OutboxMapper.toSnakeCase('storeId'), 'store_id');
      expect(OutboxMapper.toSnakeCase('serialNumber'), 'serial_number');
      expect(OutboxMapper.toSnakeCase('store_id'), 'store_id');
      expect(OutboxMapper.toSnakeCase('id'), 'id');
    });
  });

  group('RetryPolicy', () {
    const policy = RetryPolicy();

    test('a espera dobra a cada falha e tem teto', () {
      expect(policy.delayFor(0), Duration.zero);
      expect(policy.delayFor(1), const Duration(seconds: 30));
      expect(policy.delayFor(2), const Duration(minutes: 1));
      expect(policy.delayFor(4), const Duration(minutes: 4));
      expect(policy.delayFor(10), const Duration(minutes: 30));
      expect(policy.delayFor(1000), const Duration(minutes: 30));
    });

    test('isDue respeita a última tentativa', () {
      final last = DateTime(2026, 11, 18, 10);
      expect(policy.isDue(0, null, last), isTrue);
      expect(policy.isDue(1, null, last), isTrue);
      expect(policy.isDue(1, last, last.add(const Duration(seconds: 29))),
          isFalse);
      expect(policy.isDue(1, last, last.add(const Duration(seconds: 30))),
          isTrue);
      expect(
        policy.nextAttemptAt(2, last),
        last.add(const Duration(minutes: 1)),
      );
    });
  });
}
