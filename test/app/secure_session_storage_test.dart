import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/storage/key_value_store.dart';
import 'package:kym/app/storage/secure_session_storage.dart';

class _ThrowingStore implements KeyValueStore {
  @override
  Future<String?> read(String key) async => throw Exception('keystore');

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

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
      await store.read(SecureSessionStorage.sessionKey),
      '{"access_token":"abc"}',
    );
  });

  test('removePersistedSession (logout) apaga o token', () async {
    await storage.persistSession('token');
    await storage.removePersistedSession();

    expect(await storage.hasAccessToken(), isFalse);
    expect(await store.read(SecureSessionStorage.sessionKey), isNull);
  });

  test('falha ao ler o armazenamento vira "sem sessão"', () async {
    final broken = SecureSessionStorage(_ThrowingStore());

    expect(await broken.hasAccessToken(), isFalse);
    expect(await broken.accessToken(), isNull);
  });
}
