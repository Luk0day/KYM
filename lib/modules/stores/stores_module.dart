import 'package:flutter_modular/flutter_modular.dart';

import '../../app/sync/sync_service.dart';

import 'domain/repositories/store_list_repository.dart';
import 'domain/services/store_sync_trigger.dart';
import 'domain/usecases/filter_stores.dart';
import 'domain/usecases/refresh_stores.dart';
import 'domain/usecases/watch_store_detail.dart';
import 'domain/usecases/watch_stores.dart';
import 'external/datasources/drift_store_local_datasource.dart';
import 'infra/datasources/store_local_datasource.dart';
import 'infra/repositories/store_list_repository_impl.dart';
import 'infra/services/noop_store_sync_trigger.dart';
import 'infra/services/sync_service_store_sync_trigger.dart';

/// Dependências da tela Lojas (a rota fica na casca, no `HomeModule`).
/// Exige o `AppDatabase` registrado no `AppModule`.
class StoresModule extends Module {
  StoresModule({this.syncService});

  /// Sincronização do app (B19/B20). Nula no modo fake, que não sincroniza:
  /// aí a tela não afirma que os dados estão em dia.
  final SyncService? syncService;

  @override
  void register(ModularContext c) {
    final sync = syncService;
    c
      ..addLazySingleton<StoreLocalDataSource>(DriftStoreLocalDataSource.new)
      ..addLazySingleton<StoreListRepository>(StoreListRepositoryImpl.new)
      ..addLazySingleton<StoreSyncTrigger>(
        () => sync == null
            ? NoopStoreSyncTrigger()
            : SyncServiceStoreSyncTrigger(sync),
      )
      ..addLazySingleton<WatchStores>(WatchStores.new)
      ..addLazySingleton<WatchStoreDetail>(WatchStoreDetail.new)
      ..addLazySingleton<FilterStores>(FilterStores.new)
      ..addLazySingleton<RefreshStores>(RefreshStores.new);
  }
}
