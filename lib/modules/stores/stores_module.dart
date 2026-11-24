import 'package:flutter_modular/flutter_modular.dart';

import 'domain/repositories/store_list_repository.dart';
import 'domain/services/sync_service.dart';
import 'domain/usecases/filter_stores.dart';
import 'domain/usecases/refresh_stores.dart';
import 'domain/usecases/watch_stores.dart';
import 'external/datasources/drift_store_local_datasource.dart';
import 'infra/datasources/store_local_datasource.dart';
import 'infra/repositories/store_list_repository_impl.dart';
import 'infra/services/noop_sync_service.dart';

/// Dependências da tela Lojas (a rota fica na casca, no `HomeModule`).
/// Exige o `AppDatabase` registrado no `AppModule`.
class StoresModule extends Module {
  @override
  void register(ModularContext c) {
    c
      ..addLazySingleton<StoreLocalDataSource>(DriftStoreLocalDataSource.new)
      ..addLazySingleton<StoreListRepository>(StoreListRepositoryImpl.new)
      // TODO(B20): trocar pelo serviço de sincronização real.
      ..addLazySingleton<SyncService>(NoopSyncService.new)
      ..addLazySingleton<WatchStores>(WatchStores.new)
      ..addLazySingleton<FilterStores>(FilterStores.new)
      ..addLazySingleton<RefreshStores>(RefreshStores.new);
  }
}
