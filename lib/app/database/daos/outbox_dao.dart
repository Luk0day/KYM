import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'outbox_dao.g.dart';

/// Fila de operações feitas offline. Este DAO enfileira e controla o estado
/// dos itens; quem lê a fila e envia ao Supabase é o `SyncService` (B19).
@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  /// Estados que ainda precisam chegar ao servidor.
  static const _unsent = [
    OutboxStatus.pending,
    OutboxStatus.processing,
    OutboxStatus.failed,
  ];

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
        ..orderBy(_creationOrder))
      .get();

  /// Itens que podem ser enviados: pendentes e falhos que ainda têm
  /// tentativas, na ordem em que foram criados. A espera entre tentativas é
  /// decidida por quem processa a fila.
  Future<List<OutboxEntry>> listRetryable({required int maxAttempts}) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.status.equalsValue(OutboxStatus.pending) |
                  (o.status.equalsValue(OutboxStatus.failed) &
                      o.attempts.isSmallerThanValue(maxAttempts)),
            )
            ..orderBy(_creationOrder))
          .get();

  /// Itens falhos que esgotaram as tentativas e só voltam por ação manual.
  Future<List<OutboxEntry>> listExhausted({required int maxAttempts}) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.status.equalsValue(OutboxStatus.failed) &
                  o.attempts.isBiggerOrEqualValue(maxAttempts),
            )
            ..orderBy(_creationOrder))
          .get();

  /// Não grava [Outbox.lastAttemptAt]: só conta como tentativa o envio que
  /// termina (concluído ou falho). Se a rede cair, o item volta com [release]
  /// sem mexer na espera entre tentativas.
  Future<void> markProcessing(int id) =>
      _setStatus(id, OutboxStatus.processing);

  /// Marca como concluído e grava a hora do envio, usada pela limpeza.
  Future<void> markDone(int id, {DateTime? at}) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion(
          status: const Value(OutboxStatus.done),
          lastAttemptAt: Value(at ?? DateTime.now()),
        ),
      );

  /// Marca o item como concluído e grava [syncedAt] no registro local a que
  /// ele se refere, na mesma transação. Exclusões não têm registro a marcar.
  Future<void> markDoneAndSynced(OutboxEntry entry, DateTime syncedAt) =>
      transaction(() async {
        await markDone(entry.id, at: syncedAt);
        if (entry.operation != OutboxOperation.delete) {
          await _markEntitySynced(entry.entity, entry.entityId, syncedAt);
        }
      });

  /// Marca como falho, guarda o erro, soma uma tentativa e grava a hora dela
  /// (base da espera até a próxima).
  Future<void> markFailed(int id, String error, {DateTime? at}) =>
      transaction(() async {
        final current =
            await (select(outbox)..where((o) => o.id.equals(id))).getSingle();
        await (update(outbox)..where((o) => o.id.equals(id))).write(
          OutboxCompanion(
            status: const Value(OutboxStatus.failed),
            attempts: Value(current.attempts + 1),
            lastError: Value(error),
            lastAttemptAt: Value(at ?? DateTime.now()),
          ),
        );
      });

  /// Devolve o item ao estado em que estava antes do envio, sem gastar
  /// tentativa nem mexer na hora da última tentativa. Usado quando a rede cai
  /// no meio do envio.
  Future<void> release(int id, OutboxStatus previous) =>
      _setStatus(id, previous);

  /// Itens que ficaram em `processing` (o app fechou no meio do envio) voltam
  /// a `pending`. Devolve quantos foram liberados.
  Future<int> resetProcessing() =>
      (update(outbox)
            ..where((o) => o.status.equalsValue(OutboxStatus.processing)))
          .write(const OutboxCompanion(status: Value(OutboxStatus.pending)));

  /// Ação manual (B16): devolve os falhos à fila com as tentativas zeradas.
  Future<int> resetFailed() =>
      (update(outbox)..where((o) => o.status.equalsValue(OutboxStatus.failed)))
          .write(
        const OutboxCompanion(
          status: Value(OutboxStatus.pending),
          attempts: Value(0),
          lastError: Value(null),
        ),
      );

  /// Apaga os itens concluídos antes de [olderThan] (pela data do último
  /// envio; sem ela, pela de criação). Devolve quantos foram apagados.
  Future<int> purgeDone({required DateTime olderThan}) =>
      (delete(outbox)
            ..where(
              (o) =>
                  o.status.equalsValue(OutboxStatus.done) &
                  coalesce([o.lastAttemptAt, o.createdAt])
                      .isSmallerThanValue(olderThan),
            ))
          .go();

  /// Quantos itens ainda não chegaram ao servidor (pendentes, em envio ou
  /// falhos). Alimenta o indicador de sync (B21).
  Stream<int> watchPendingCount() => _watchCount(
        outbox.status.isIn(_unsent.map((s) => s.name)),
      );

  /// Quantos itens falharam (inclui os que ainda vão ser tentados de novo).
  Stream<int> watchFailedCount() =>
      _watchCount(outbox.status.equalsValue(OutboxStatus.failed));

  /// Id do item mais recente da fila. Muda a cada enfileiramento, então serve
  /// de gatilho para enviar logo após uma operação feita com rede.
  Stream<int?> watchLastId() {
    final maxId = outbox.id.max();
    return (selectOnly(outbox)..addColumns([maxId]))
        .map((row) => row.read(maxId))
        .watchSingle()
        .distinct();
  }

  Stream<int> _watchCount(Expression<bool> filter) {
    final count = outbox.id.count();
    return (selectOnly(outbox)
          ..addColumns([count])
          ..where(filter))
        .map((row) => row.read(count) ?? 0)
        .watchSingle()
        .distinct();
  }

  Future<void> _markEntitySynced(
    OutboxEntity entity,
    String id,
    DateTime at,
  ) {
    final db = attachedDatabase;
    return switch (entity) {
      OutboxEntity.store => (db.update(db.stores)
            ..where((t) => t.id.equals(id)))
          .write(StoresCompanion(syncedAt: Value(at))),
      OutboxEntity.equipment => (db.update(db.equipments)
            ..where((t) => t.id.equals(id)))
          .write(EquipmentsCompanion(syncedAt: Value(at))),
      OutboxEntity.maintenanceOrder => (db.update(db.maintenanceOrders)
            ..where((t) => t.id.equals(id)))
          .write(MaintenanceOrdersCompanion(syncedAt: Value(at))),
      OutboxEntity.photo => (db.update(db.photos)
            ..where((t) => t.id.equals(id)))
          .write(PhotosCompanion(syncedAt: Value(at))),
    };
  }

  static List<OrderClauseGenerator<$OutboxTable>> get _creationOrder => [
        (o) => OrderingTerm.asc(o.createdAt),
        (o) => OrderingTerm.asc(o.id),
      ];

  Future<void> _setStatus(int id, OutboxStatus status) =>
      (update(outbox)..where((o) => o.id.equals(id)))
          .write(OutboxCompanion(status: Value(status)));
}
