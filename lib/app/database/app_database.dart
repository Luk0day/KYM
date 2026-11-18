import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/equipments_dao.dart';
import 'daos/maintenance_orders_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/photos_dao.dart';
import 'daos/pull_dao.dart';
import 'daos/stores_dao.dart';
import 'enums.dart';
import 'tables.dart';

export 'enums.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Stores, Equipments, MaintenanceOrders, Photos, Outbox, SyncState],
  daos: [
    StoresDao,
    EquipmentsDao,
    MaintenanceOrdersDao,
    PhotosDao,
    OutboxDao,
    PullDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Banco real, persistido no aparelho.
  AppDatabase() : super(driftDatabase(name: 'kym'));

  /// Para testes: recebe o executor, por exemplo `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Próximas versões: aumente `schemaVersion` e migre por etapas, sem
          // recriar tabelas (isso apagaria dados offline ainda não enviados).
          if (from < 2) {
            // B19: espera entre tentativas e limpeza da outbox.
            await m.addColumn(outbox, outbox.lastAttemptAt);
          }
          if (from < 3) {
            // B20: baixada incremental por updated_at.
            await m.addColumn(stores, stores.updatedAt);
            await m.addColumn(equipments, equipments.updatedAt);
            await m.createTable(syncState);
          }
        },
        beforeOpen: (details) async {
          // O SQLite não aplica chaves estrangeiras por padrão.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
