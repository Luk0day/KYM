import 'package:supabase_flutter/supabase_flutter.dart';

import 'key_value_store.dart';
import 'storage_keys.dart';

class LegacySessionMigrator {
  LegacySessionMigrator({required this.legacy, required this.target});

  final LocalStorage legacy;
  final KeyValueStore target;

  static String sessionKeyFor(String supabaseUrl) {
    final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
    return 'sb-$projectRef-auth-token';
  }

  Future<void> migrate() async {
    try {
      await legacy.initialize();
      if (!await legacy.hasAccessToken()) {
        return;
      }

      final legacySession = await legacy.accessToken();
      final targetHasSession =
          await target.read(StorageKeys.supabaseSession) != null;

      if (legacySession != null && !targetHasSession) {
        await target.write(StorageKeys.supabaseSession, legacySession);
      }
      await legacy.removePersistedSession();
    } catch (_) {
      return;
    }
  }
}