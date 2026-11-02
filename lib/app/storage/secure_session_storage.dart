import 'package:supabase_flutter/supabase_flutter.dart';

import 'key_value_store.dart';

class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this._store);

  static const String sessionKey = 'kym.supabase.session';

  final KeyValueStore _store;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _safeRead()) != null;

  @override
  Future<String?> accessToken() => _safeRead();

  @override
  Future<void> persistSession(String persistSessionString) {
    return _store.write(sessionKey, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() => _store.delete(sessionKey);

  Future<String?> _safeRead() async {
    try {
      return await _store.read(sessionKey);
    } catch (_) {
      return null;
    }
  }
}