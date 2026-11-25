import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'pull_dao.g.dart';

/// Linha vinda do servidor, pronta para gravar no espelho local.
class PulledRow<D> {
  const PulledRow({required this.id, required this.insert, Insertable<D>? update})
      : update = update ?? insert;

  final String id;

  /// Gravado quando a linha ainda não existe no aparelho.
  final Insertable<D> insert;

  /// Gravado quando a linha já existe. Só traz colunas do servidor, para não
  /// apagar o que é local (por exemplo o arquivo e o estado de envio da foto).
  final Insertable<D> update;
}

/// Gravações da baixada incremental (B20): marcas por tabela, upsert das
/// linhas do servidor e remoção do que sumiu dele.
@DriftAccessor(tables: [SyncState])
class PullDao extends DatabaseAccessor<AppDatabase> with _$PullDaoMixin {
  PullDao(super.db);

  /// Limite de variáveis por consulta (o SQLite antigo aceita 999).
  static const _chunk = 500;

  Future<SyncStateEntry?> stateFor(String remoteTable) => (select(syncState)
        ..where((s) => s.remoteTable.equals(remoteTable)))
      .getSingleOrNull();

  Future<void> saveCursor(String remoteTable, String cursor) =>
      into(syncState).insert(
        SyncStateCompanion.insert(
          remoteTable: remoteTable,
          cursor: Value(cursor),
        ),
        onConflict: DoUpdate(
          (_) => SyncStateCompanion(cursor: Value(cursor)),
        ),
      );

  /// Registra a reconciliação completa de [remoteTable], feita por [userId].
  Future<void> markFullPull(
    String remoteTable,
    DateTime at, {
    String? userId,
  }) =>
      into(syncState).insert(
        SyncStateCompanion.insert(
          remoteTable: remoteTable,
          lastFullPullAt: Value(at),
          userId: Value(userId),
        ),
        onConflict: DoUpdate(
          (_) => SyncStateCompanion(
            lastFullPullAt: Value(at),
            userId: Value(userId),
          ),
        ),
      );

  /// Apaga as marcas: o próximo pull traz tudo de novo. Para o logout (B16).
  Future<int> clearState() => delete(syncState).go();

  /// Grava as linhas numa transação: insere as novas e atualiza as que já
  /// existem.
  Future<void> upsertAll<T extends Table, D>(
    TableInfo<T, D> table,
    List<PulledRow<D>> rows,
  ) {
    if (rows.isEmpty) return Future.value();
    return batch((b) {
      for (final row in rows) {
        b.insert(
          table,
          row.insert,
          onConflict: DoUpdate((_) => row.update),
        );
      }
    });
  }

  /// Quais destes ids existem em [table].
  Future<Set<String>> existingIds(
    TableInfo<Table, dynamic> table,
    Iterable<String> ids,
  ) async {
    final wanted = ids.toSet().toList();
    final found = <String>{};
    for (var i = 0; i < wanted.length; i += _chunk) {
      final chunk = wanted.sublist(i, (i + _chunk).clamp(0, wanted.length));
      final rows = await customSelect(
        'SELECT id FROM ${table.actualTableName} '
        'WHERE id IN (${List.filled(chunk.length, '?').join(', ')})',
        variables: [for (final id in chunk) Variable.withString(id)],
        readsFrom: {table},
      ).get();
      found.addAll(rows.map((r) => r.read<String>('id')));
    }
    return found;
  }

  /// Lojas e equipamentos acima destes registros: ordem → equipamento e
  /// loja; equipamento → loja. Ids que não são de ordem nem de equipamento
  /// são ignorados.
  Future<Set<String>> ancestorsOf(Iterable<String> ids) async {
    final db = attachedDatabase;
    final orderIds = ids.toSet().toList();
    final equipmentIds = <String>{...orderIds};
    final ancestors = <String>{};

    for (var i = 0; i < orderIds.length; i += _chunk) {
      final chunk = orderIds.sublist(i, (i + _chunk).clamp(0, orderIds.length));
      final rows = await (db.select(db.maintenanceOrders)
            ..where((o) => o.id.isIn(chunk)))
          .get();
      for (final row in rows) {
        ancestors
          ..add(row.storeId)
          ..add(row.equipmentId);
        equipmentIds.add(row.equipmentId);
      }
    }

    final equipment = equipmentIds.toList();
    for (var i = 0; i < equipment.length; i += _chunk) {
      final chunk =
          equipment.sublist(i, (i + _chunk).clamp(0, equipment.length));
      final rows = await (db.select(db.equipments)
            ..where((e) => e.id.isIn(chunk)))
          .get();
      ancestors.addAll(rows.map((e) => e.storeId));
    }
    return ancestors;
  }

  /// Apaga de [table] as linhas cujo id não está em [keep]. As filhas vão
  /// junto pela chave estrangeira (cascade). Devolve quantas foram apagadas.
  Future<int> deleteMissing(
    TableInfo<Table, dynamic> table,
    Set<String> keep,
  ) =>
      transaction(() async {
        final local = await customSelect(
          'SELECT id FROM ${table.actualTableName}',
          readsFrom: {table},
        ).get();
        final gone = [
          for (final row in local)
            if (!keep.contains(row.read<String>('id'))) row.read<String>('id'),
        ];
        for (var i = 0; i < gone.length; i += _chunk) {
          final chunk = gone.sublist(i, (i + _chunk).clamp(0, gone.length));
          await customUpdate(
            'DELETE FROM ${table.actualTableName} '
            'WHERE id IN (${List.filled(chunk.length, '?').join(', ')})',
            variables: [for (final id in chunk) Variable.withString(id)],
            updates: {table},
            updateKind: UpdateKind.delete,
          );
        }
        return gone.length;
      });
}
