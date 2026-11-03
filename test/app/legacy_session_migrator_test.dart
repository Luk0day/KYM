import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/storage/key_value_store.dart';
import 'package:kym/app/storage/legacy_session_migrator.dart';
import 'package:kym/app/storage/storage_keys.dart';

import '../support/failing_key_value_store.dart';
import '../support/in_memory_local_storage.dart';

void main() {
  late InMemoryKeyValueStore target;

  setUp(() => target = InMemoryKeyValueStore());

  test(
    'move a sessão legada para o armazenamento seguro e limpa a legada',
    () async {
      final legacy = InMemoryLocalStorage('legacy-session');

      await LegacySessionMigrator(legacy: legacy, target: target).migrate();

      expect(await target.read(StorageKeys.supabaseSession), 'legacy-session');
      expect(legacy.session, isNull);
    },
  );

  test('sem sessão legada, não altera o destino', () async {
    final legacy = InMemoryLocalStorage();

    await LegacySessionMigrator(legacy: legacy, target: target).migrate();

    expect(await target.read(StorageKeys.supabaseSession), isNull);
  });

  test('mantém a sessão existente no destino e limpa a legada', () async {
    final legacy = InMemoryLocalStorage('legacy-session');
    await target.write(StorageKeys.supabaseSession, 'current-session');

    await LegacySessionMigrator(legacy: legacy, target: target).migrate();

    expect(await target.read(StorageKeys.supabaseSession), 'current-session');
    expect(legacy.session, isNull);
  });

  test('falha ao gravar não propaga e preserva a sessão legada', () async {
    final legacy = InMemoryLocalStorage('legacy-session');
    final failingTarget = FailingKeyValueStore(failWrites: true);

    await expectLater(
      LegacySessionMigrator(legacy: legacy, target: failingTarget).migrate(),
      completes,
    );

    expect(legacy.session, 'legacy-session');
  });

  test('monta a chave legada a partir do host do projeto', () {
    expect(
      LegacySessionMigrator.sessionKeyFor('https://abcdefgh.supabase.co'),
      'sb-abcdefgh-auth-token',
    );
  });
}
