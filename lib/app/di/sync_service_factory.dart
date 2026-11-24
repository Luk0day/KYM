import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../database/app_database.dart';
import '../sync/external/supabase_remote_sync_datasource.dart';
import '../sync/sync_service.dart';

/// No modo fake não há Supabase, então não há sincronização: o app roda só com
/// o seed local.
SyncService? createSyncService(AppDatabase database) {
  if (Env.useFakeAuth) return null;

  return SyncService(
    outbox: database.outboxDao,
    remote: SupabaseRemoteSyncDataSource(Supabase.instance.client),
  );
}
