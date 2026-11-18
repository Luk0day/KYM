import 'package:drift/drift.dart';

import '../../database/app_database.dart';
import '../../database/daos/pull_dao.dart';

/// Resultado da gravação de uma página.
class PageWriteResult {
  const PageWriteResult({
    required this.ids,
    required this.written,
    required this.skipped,
  });

  /// Ids de todas as linhas da página, gravadas ou não. Na reconciliação
  /// completa, contam como "existe no servidor".
  final List<String> ids;
  final int written;

  /// Linhas não gravadas: com operação local pendente, inválidas ou cujo
  /// registro pai não existe no aparelho.
  final int skipped;
}

/// Uma tabela do servidor espelhada no Drift: como converter a linha e de
/// quais registros pai ela depende.
class PullTable<T extends Table, D> {
  const PullTable({
    required this.remote,
    required this.local,
    required this.map,
    this.parents = const {},
  });

  /// Nome no Postgres.
  final String remote;

  final TableInfo<T, D> Function(AppDatabase db) local;

  /// Converte a linha do servidor. Lança [FormatException] se ela não fizer
  /// sentido (campo obrigatório faltando, enum desconhecido).
  final PulledRow<D> Function(Map<String, dynamic> json, DateTime syncedAt)
      map;

  /// Coluna da chave estrangeira → tabela pai (local). O pai precisa existir
  /// no aparelho, senão o SQLite recusa a linha.
  final Map<String, TableInfo<Table, dynamic> Function(AppDatabase db)>
      parents;

  /// Grava uma página. Pula as linhas de [protectedIds] (operação local ainda
  /// não enviada), as inválidas e as órfãs.
  Future<PageWriteResult> write(
    AppDatabase db,
    List<Map<String, dynamic>> rows, {
    required Set<String> protectedIds,
    required DateTime syncedAt,
  }) async {
    final ids = <String>[];
    final candidates = <(Map<String, dynamic>, PulledRow<D>)>[];
    var skipped = 0;

    for (final json in rows) {
      final id = json['id'];
      if (id is! String) {
        skipped++;
        continue;
      }
      ids.add(id);
      if (protectedIds.contains(id)) {
        skipped++;
        continue;
      }
      try {
        candidates.add((json, map(json, syncedAt)));
      } on FormatException {
        skipped++;
      }
    }

    // Pais que existem: os que já estavam no aparelho mais os desta página
    // (uma tabela não é pai dela mesma, então basta consultar o banco).
    final existing = <String, Set<String>>{};
    for (final MapEntry(key: column, value: parent) in parents.entries) {
      existing[column] = await db.pullDao.existingIds(
        parent(db),
        candidates.map((c) => c.$1[column]).whereType<String>(),
      );
    }

    final accepted = <PulledRow<D>>[];
    for (final (json, row) in candidates) {
      final orphan = existing.entries.any(
        (e) => !e.value.contains(json[e.key]),
      );
      if (orphan) {
        skipped++;
      } else {
        accepted.add(row);
      }
    }

    await db.pullDao.upsertAll(local(db), accepted);
    return PageWriteResult(
      ids: ids,
      written: accepted.length,
      skipped: skipped,
    );
  }
}

/// Tabelas baixadas, na ordem das chaves estrangeiras: o pai chega antes do
/// filho. checklist_items, signatures e visits entram quando ganharem espelho
/// no Drift.
final List<PullTable<Table, dynamic>> pullTables = [
  PullTable<$StoresTable, Store>(
    remote: 'stores',
    local: (db) => db.stores,
    map: _store,
  ),
  PullTable<$EquipmentsTable, Equipment>(
    remote: 'equipment',
    local: (db) => db.equipments,
    map: _equipment,
    parents: {'store_id': (db) => db.stores},
  ),
  PullTable<$MaintenanceOrdersTable, MaintenanceOrder>(
    remote: 'maintenance_orders',
    local: (db) => db.maintenanceOrders,
    map: _order,
    parents: {
      'store_id': (db) => db.stores,
      'equipment_id': (db) => db.equipments,
    },
  ),
  PullTable<$PhotosTable, Photo>(
    remote: 'photos',
    local: (db) => db.photos,
    map: _photo,
    parents: {'order_id': (db) => db.maintenanceOrders},
  ),
];

PulledRow<Store> _store(Map<String, dynamic> j, DateTime syncedAt) {
  final row = StoresCompanion(
    id: Value(_text(j, 'id')),
    name: Value(_text(j, 'name')),
    code: Value(_textOrNull(j, 'code')),
    address: Value(_textOrNull(j, 'address')),
    city: Value(_textOrNull(j, 'city')),
    latitude: Value(_doubleOrNull(j, 'latitude')),
    longitude: Value(_doubleOrNull(j, 'longitude')),
    qrToken: Value(_text(j, 'qr_token')),
    active: Value(_bool(j, 'active')),
    createdAt: Value(_timestamp(j, 'created_at')),
    updatedAt: Value(_timestamp(j, 'updated_at')),
    syncedAt: Value(syncedAt),
  );
  return PulledRow(id: row.id.value, insert: row);
}

PulledRow<Equipment> _equipment(Map<String, dynamic> j, DateTime syncedAt) {
  final row = EquipmentsCompanion(
    id: Value(_text(j, 'id')),
    storeId: Value(_text(j, 'store_id')),
    name: Value(_text(j, 'name')),
    category: Value(_textOrNull(j, 'category')),
    brand: Value(_textOrNull(j, 'brand')),
    model: Value(_textOrNull(j, 'model')),
    serialNumber: Value(_textOrNull(j, 'serial_number')),
    qrToken: Value(_text(j, 'qr_token')),
    status: Value(_text(j, 'status')),
    installedAt: Value(_dateOrNull(j, 'installed_at')),
    notes: Value(_textOrNull(j, 'notes')),
    createdAt: Value(_timestamp(j, 'created_at')),
    updatedAt: Value(_timestamp(j, 'updated_at')),
    syncedAt: Value(syncedAt),
  );
  return PulledRow(id: row.id.value, insert: row);
}

PulledRow<MaintenanceOrder> _order(Map<String, dynamic> j, DateTime syncedAt) {
  final row = MaintenanceOrdersCompanion(
    id: Value(_text(j, 'id')),
    equipmentId: Value(_text(j, 'equipment_id')),
    storeId: Value(_text(j, 'store_id')),
    type: Value(_enum(j, 'type', OrderType.values, (e) => e.dbValue)),
    status: Value(_enum(j, 'status', OrderStatus.values, (e) => e.dbValue)),
    description: Value(_textOrNull(j, 'description')),
    notes: Value(_textOrNull(j, 'notes')),
    scheduledFor: Value(_dateOrNull(j, 'scheduled_for')),
    openedBy: Value(_textOrNull(j, 'opened_by')),
    assignedTo: Value(_textOrNull(j, 'assigned_to')),
    startedAt: Value(_timestampOrNull(j, 'started_at')),
    completedAt: Value(_timestampOrNull(j, 'completed_at')),
    createdAt: Value(_timestamp(j, 'created_at')),
    updatedAt: Value(_timestamp(j, 'updated_at')),
    syncedAt: Value(syncedAt),
  );
  return PulledRow(id: row.id.value, insert: row);
}

PulledRow<Photo> _photo(Map<String, dynamic> j, DateTime syncedAt) {
  final update = PhotosCompanion(
    id: Value(_text(j, 'id')),
    orderId: Value(_text(j, 'order_id')),
    storagePath: Value(_text(j, 'storage_path')),
    kind: Value(_enum(j, 'kind', PhotoKind.values, (e) => e.dbValue)),
    takenAt: Value(_timestamp(j, 'taken_at')),
    createdBy: Value(_textOrNull(j, 'created_by')),
    syncedAt: Value(syncedAt),
  );
  // Foto nova vinda do servidor: o arquivo já está no Storage. Se a foto já
  // existe no aparelho, o arquivo local e o estado do envio (B23) ficam.
  final insert = update.copyWith(
    uploadStatus: const Value(PhotoUploadStatus.uploaded),
  );
  return PulledRow(id: update.id.value, insert: insert, update: update);
}

String _text(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value is String) return value;
  throw FormatException('campo "$key" ausente ou não é texto', value);
}

String? _textOrNull(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('campo "$key" não é texto', value);
}

double? _doubleOrNull(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value == null) return null;
  if (value is num) return value.toDouble();
  throw FormatException('campo "$key" não é número', value);
}

bool _bool(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value is bool) return value;
  throw FormatException('campo "$key" não é booleano', value);
}

DateTime _timestamp(Map<String, dynamic> j, String key) =>
    _timestampOrNull(j, key) ??
    (throw FormatException('campo "$key" ausente', j[key]));

DateTime? _timestampOrNull(Map<String, dynamic> j, String key) {
  final value = j[key];
  if (value == null) return null;
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw FormatException('campo "$key" não é data e hora', value);
  }
  return parsed;
}

/// Colunas `date` do Postgres (`2026-11-20`) viram meia-noite local.
DateTime? _dateOrNull(Map<String, dynamic> j, String key) {
  final value = _timestampOrNull(j, key);
  return value == null ? null : DateTime(value.year, value.month, value.day);
}

E _enum<E>(
  Map<String, dynamic> j,
  String key,
  List<E> values,
  String Function(E) dbValue,
) {
  final value = j[key];
  for (final candidate in values) {
    if (dbValue(candidate) == value) return candidate;
  }
  throw FormatException('valor desconhecido em "$key"', value);
}
