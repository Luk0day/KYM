import 'package:flutter_modular/flutter_modular.dart';
import 'package:uuid/uuid.dart';

import '../modules/auth/auth_module.dart';
import '../modules/auth/infra/datasources/auth_datasource.dart';
import '../modules/equipment/domain/repositories/equipment_repository.dart';
import '../modules/equipment/infra/repositories/equipment_repository_impl.dart';
import '../modules/home/home_module.dart';
import '../modules/home/home_routes.dart';
import '../modules/orders/domain/repositories/order_repository.dart';
import '../modules/orders/infra/repositories/order_repository_impl.dart';
import '../modules/stores/domain/repositories/store_repository.dart';
import '../modules/stores/infra/repositories/store_repository_impl.dart';
import 'database/app_database.dart';
import 'database/daos/equipments_dao.dart';
import 'database/daos/maintenance_orders_dao.dart';
import 'database/daos/outbox_dao.dart';
import 'database/daos/photos_dao.dart';
import 'database/daos/stores_dao.dart';

/// As fábricas são injetadas para que testes e o modo fake troquem o Supabase
/// e o banco (por exemplo `AppDatabase.forTesting(NativeDatabase.memory())`)
/// sem alterar os módulos.
class AppModule extends Module {
  AppModule({
    required this.authDataSourceFactory,
    AppDatabase Function()? databaseFactory,
  }) : databaseFactory = databaseFactory ?? AppDatabase.new;

  final AuthDataSource Function() authDataSourceFactory;
  final AppDatabase Function() databaseFactory;

  @override
  void register(ModularContext c) {
    c
      // Banco local: um só para o app todo. Lazy, então só abre quando alguém
      // pedir.
      ..addLazySingleton<AppDatabase>(databaseFactory)
      ..addLazySingleton<StoresDao>((AppDatabase db) => db.storesDao)
      ..addLazySingleton<EquipmentsDao>((AppDatabase db) => db.equipmentsDao)
      ..addLazySingleton<MaintenanceOrdersDao>(
        (AppDatabase db) => db.maintenanceOrdersDao,
      )
      ..addLazySingleton<PhotosDao>((AppDatabase db) => db.photosDao)
      ..addLazySingleton<OutboxDao>((AppDatabase db) => db.outboxDao)
      // Repositórios local-first: as telas leem sempre do Drift.
      ..addLazySingleton<StoreRepository>(StoreRepositoryImpl.new)
      ..addLazySingleton<EquipmentRepository>(EquipmentRepositoryImpl.new)
      ..addLazySingleton<OrderRepository>(
        (AppDatabase db) =>
            OrderRepositoryImpl(db, idGenerator: () => const Uuid().v4()),
      )
      ..module(
        AuthModule(
          dataSourceFactory: authDataSourceFactory,
          authenticatedRoute: HomeRoutes.root,
        ),
      )
      ..module(HomeModule());
  }
}
