import 'key_value_store.dart';
import 'storage_keys.dart';

class InstallationGuard {
  InstallationGuard({required this.marker, required this.secureStore});

  final KeyValueStore marker;
  final KeyValueStore secureStore;

  Future<void> discardStaleSession() async {
    try {
      final alreadyInstalled =
          await marker.read(StorageKeys.installationMarker) != null;
      if (alreadyInstalled) {
        return;
      }
      await secureStore.delete(StorageKeys.supabaseSession);
      await marker.write(StorageKeys.installationMarker, 'true');
    } catch (_) {
      return;
    }
  }
}