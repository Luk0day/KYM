import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/storage/installation_guard.dart';
import 'package:kym/app/storage/key_value_store.dart';
import 'package:kym/app/storage/legacy_session_migrator.dart';
import 'package:kym/app/storage/secure_session_storage.dart';
import 'package:kym/app/storage/storage_keys.dart';

import '../support/failing_key_value_store.dart';
import '../support/in_memory_local_storage.dart';

void main() {
  late InMemoryKeyValueStore store;
  late SecureSessionStorage storage;

  setUp(() {
    store = InMemoryKeyValueStore();
    storage = SecureSessionStorage(store);
  });

  test('sem sessão salva, não há token', () async {
    expect(await storage.hasAccessToken(), isFalse);
    expect(await storage.accessToken(), isNull);
  });

  test('persistSession guarda no armazenamento seguro', () async {
    await storage.persistSession('{"access_token":"abc"}');

    expect(await storage.hasAccessToken(), isTrue);
    expect(await storage.accessToken(), '{"access_token":"abc"}');
    expect(
      await store.read(StorageKeys.supabaseSession),
      '{"access_token":"abc"}',
    );
  });

  test('removePersistedSession apaga o token no logout', () async {
    await storage.persistSession('token');
    await storage.removePersistedSession();

    expect(await storage.hasAccessToken(), isFalse);
    expect(await store.read(StorageKeys.supabaseSession), isNull);
  });

  test('falha ao ler o armazenamento vira sem sessão', () async {
    final broken = SecureSessionStorage(FailingKeyValueStore(failReads: true));

    expect(await broken.hasAccessToken(), isFalse);
    expect(await broken.accessToken(), isNull);
  });

  test('initialize sem dependências opcionais mantém a sessão', () async {
    await storage.persistSession('token');
    await storage.initialize();

    expect(await storage.accessToken(), 'token');
  });

  test('initialize descarta a sessão obsoleta e migra a legada', () async {
    final marker = InMemoryKeyValueStore();
    final legacy = InMemoryLocalStorage('legacy-session');
    await store.write(StorageKeys.supabaseSession, 'stale-session');

    final configured = SecureSessionStorage(
      store,
      installationGuard: InstallationGuard(marker: marker, secureStore: store),
      legacyMigrator: LegacySessionMigrator(legacy: legacy, target: store),
    );

    await configured.initialize();

    expect(await configured.accessToken(), 'legacy-session');
    expect(legacy.session, isNull);
    expect(await marker.read(StorageKeys.installationMarker), isNotNull);
  });
}
