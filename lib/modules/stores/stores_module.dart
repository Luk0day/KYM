import 'package:flutter_modular/flutter_modular.dart';

import '../auth/auth_routes.dart';
import '../auth/presenter/controllers/session_controller.dart';
import 'domain/repositories/store_list_repository.dart';
import 'domain/services/sync_service.dart';
import 'domain/usecases/refresh_stores.dart';
import 'domain/usecases/watch_stores.dart';
import 'external/datasources/drift_store_local_datasource.dart';
import 'infra/datasources/store_local_datasource.dart';
import 'infra/repositories/store_list_repository_impl.dart';
import 'infra/services/noop_sync_service.dart';
import 'presenter/controllers/stores_controller.dart';
import 'presenter/pages/stores_page.dart';
import 'stores_routes.dart';

/// Exige o `AppDatabase` registrado no `AppModule`.
class StoresModule extends Module {
  @override
  String? get path => StoresRoutes.root;

  @override
  void register(ModularContext c) {
    c
      ..addLazySingleton<StoreLocalDataSource>(DriftStoreLocalDataSource.new)
      ..addLazySingleton<StoreListRepository>(StoreListRepositoryImpl.new)
      // TODO(B20): trocar pelo serviço de sincronização real.
      ..addLazySingleton<SyncService>(NoopSyncService.new)
      ..addLazySingleton<WatchStores>(WatchStores.new)
      ..addLazySingleton<RefreshStores>(RefreshStores.new)
      ..route(
        '/',
        guards: [
          (_) => inject<SessionController>().isAuthenticated
              ? null
              : AuthRoutes.login,
        ],
        // O controller vive só enquanto a tela estiver aberta.
        provide: (scoped) {
          scoped.addChangeNotifier<StoresController>(StoresController.new);
        },
        child: (context, _) => StoresPage(
          controller: context.read<StoresController>(),
          // TODO(B26): abrir os detalhes da loja.
          onStoreSelected: (_) {},
        ),
      );
  }
}
