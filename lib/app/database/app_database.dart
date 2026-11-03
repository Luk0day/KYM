import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/equipments_dao.dart';
import 'daos/maintenance_orders_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/photos_dao.dart';
import 'daos/stores_dao.dart';
import 'enums.dart';
import 'tables.dart';

export 'enums.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Stores, Equipments, MaintenanceOrders, Photos, Outbox],
  daos: [
    StoresDao,
    EquipmentsDao,
    MaintenanceOrdersDao,
    PhotosDao,
    OutboxDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Banco real, persistido no aparelho.
  AppDatabase() : super(driftDatabase(name: 'kym'));

  /// Para testes: recebe o executor, por exemplo `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Próximas versões: aumente `schemaVersion` e migre por etapas, sem
          // recriar tabelas (isso apagaria dados offline ainda não enviados).
          //
          //   if (from < 2) {
          //     await m.addColumn(stores, stores.novaColuna);
          //   }
          //   if (from < 3) {
          //     await m.createTable(novaTabela);
          //   }
        },
        beforeOpen: (details) async {
          // O SQLite não aplica chaves estrangeiras por padrão.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
