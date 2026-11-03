import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'outbox_dao.g.dart';

/// Fila de operações feitas offline. Este DAO só enfileira e controla o estado
/// dos itens; quem lê a fila e envia ao Supabase é outra issue.
@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// Enfileira uma operação e devolve o id do item.
  Future<int> enqueue({
    required OutboxOperation operation,
    required OutboxEntity entity,
    required String entityId,
    required Map<String, Object?> payload,
  }) =>
      into(outbox).insert(
        OutboxCompanion.insert(
          operation: operation,
          entity: entity,
          entityId: entityId,
          payload: jsonEncode(payload),
        ),
      );

  Future<OutboxEntry?> findById(int id) =>
      (select(outbox)..where((o) => o.id.equals(id))).getSingleOrNull();

  /// Itens pendentes na ordem em que foram criados.
  Future<List<OutboxEntry>> listPending() => (select(outbox)
        ..where((o) => o.status.equalsValue(OutboxStatus.pending))
        ..orderBy([
          (o) => OrderingTerm.asc(o.createdAt),
          (o) => OrderingTerm.asc(o.id),
        ]))
      .get();

  Future<void> markProcessing(int id) => _setStatus(id, OutboxStatus.processing);

  Future<void> markDone(int id) => _setStatus(id, OutboxStatus.done);

  /// Marca como falho, guarda o erro e soma uma tentativa.
  Future<void> markFailed(int id, String error) => transaction(() async {
        final current =
            await (select(outbox)..where((o) => o.id.equals(id))).getSingle();
        await (update(outbox)..where((o) => o.id.equals(id))).write(
          OutboxCompanion(
            status: const Value(OutboxStatus.failed),
            attempts: Value(current.attempts + 1),
            lastError: Value(error),
          ),
        );
      });

  Future<void> _setStatus(int id, OutboxStatus status) =>
      (update(outbox)..where((o) => o.id.equals(id)))
          .write(OutboxCompanion(status: Value(status)));
}
