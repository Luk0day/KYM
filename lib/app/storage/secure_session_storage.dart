import 'package:supabase_flutter/supabase_flutter.dart';

import 'installation_guard.dart';
import 'key_value_store.dart';
import 'legacy_session_migrator.dart';
import 'storage_keys.dart';

class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(
    this._store, {
    this.installationGuard,
    this.legacyMigrator,
  });

  final KeyValueStore _store;
  final InstallationGuard? installationGuard;
  final LegacySessionMigrator? legacyMigrator;

  @override
  Future<void> initialize() async {
    await installationGuard?.discardStaleSession();
    await legacyMigrator?.migrate();
  }

  @override
  Future<bool> hasAccessToken() async => await _safeRead() != null;

  @override
  Future<String?> accessToken() => _safeRead();

  @override
  Future<void> persistSession(String persistSessionString) {
    return _store.write(StorageKeys.supabaseSession, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() {
    return _store.delete(StorageKeys.supabaseSession);
  }

  Future<String?> _safeRead() async {
    try {
      return await _store.read(StorageKeys.supabaseSession);
    } catch (_) {
      return null;
    }
  }
}