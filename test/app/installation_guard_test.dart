import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/storage/installation_guard.dart';
import 'package:kym/app/storage/key_value_store.dart';
import 'package:kym/app/storage/storage_keys.dart';

import '../support/failing_key_value_store.dart';

void main() {
  late InMemoryKeyValueStore marker;
  late InMemoryKeyValueStore secureStore;
  late InstallationGuard guard;

  setUp(() {
    marker = InMemoryKeyValueStore();
    secureStore = InMemoryKeyValueStore();
    guard = InstallationGuard(marker: marker, secureStore: secureStore);
  });

  test(
    'primeira execução remove a sessão obsoleta e grava o marcador',
    () async {
      await secureStore.write(StorageKeys.supabaseSession, 'stale-session');

      await guard.discardStaleSession();

      expect(await secureStore.read(StorageKeys.supabaseSession), isNull);
      expect(await marker.read(StorageKeys.installationMarker), isNotNull);
    },
  );

  test('com o marcador presente, mantém a sessão', () async {
    await marker.write(StorageKeys.installationMarker, 'true');
    await secureStore.write(StorageKeys.supabaseSession, 'valid-session');

    await guard.discardStaleSession();

    expect(
      await secureStore.read(StorageKeys.supabaseSession),
      'valid-session',
    );
  });

  test(
    'sessão salva depois da primeira execução sobrevive às próximas',
    () async {
      await guard.discardStaleSession();
      await secureStore.write(StorageKeys.supabaseSession, 'new-session');

      await guard.discardStaleSession();

      expect(
        await secureStore.read(StorageKeys.supabaseSession),
        'new-session',
      );
    },
  );

  test('falha no armazenamento não propaga', () async {
    final failingGuard = InstallationGuard(
      marker: FailingKeyValueStore(failReads: true),
      secureStore: secureStore,
    );

    await expectLater(failingGuard.discardStaleSession(), completes);
  });
}
