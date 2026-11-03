import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

class PreferencesKeyValueStore implements KeyValueStore {
  PreferencesKeyValueStore(this._preferences);

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> delete(String key) => _preferences.remove(key);
}
