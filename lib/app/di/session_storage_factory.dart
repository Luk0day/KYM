import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/installation_guard.dart';
import '../storage/legacy_session_migrator.dart';
import '../storage/preferences_key_value_store.dart';
import '../storage/secure_key_value_store.dart';
import '../storage/secure_session_storage.dart';

LocalStorage createSessionStorage(String supabaseUrl) {
  final secureStore = SecureKeyValueStore();

  return SecureSessionStorage(
    secureStore,
    installationGuard: InstallationGuard(
      marker: PreferencesKeyValueStore(SharedPreferencesAsync()),
      secureStore: secureStore,
    ),
    legacyMigrator: LegacySessionMigrator(
      legacy: SharedPreferencesLocalStorage(
        persistSessionKey: LegacySessionMigrator.sessionKeyFor(supabaseUrl),
      ),
      target: secureStore,
    ),
  );
}
