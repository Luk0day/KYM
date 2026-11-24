import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/storage/key_value_store.dart';
import 'package:kym/app/storage/storage_keys.dart';
import 'package:kym/modules/auth/domain/entities/password_recovery_event.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/domain/usecases/get_current_user.dart';
import 'package:kym/modules/auth/domain/usecases/sign_out.dart';
import 'package:kym/modules/auth/domain/usecases/update_password.dart';
import 'package:kym/modules/auth/infra/datasources/auth_datasource.dart';
import 'package:kym/modules/auth/infra/models/auth_user_model.dart';
import 'package:kym/modules/auth/infra/repositories/auth_repository_impl.dart';
import 'package:kym/modules/auth/presenter/controllers/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthDataSource extends Mock implements AuthDataSource {}

class _SlowKeyValueStore extends InMemoryKeyValueStore {
  final Completer<void> readGate = Completer<void>();

  @override
  Future<String?> read(String key) async {
    await readGate.future;
    return super.read(key);
  }
}

const _tecnico = AuthUserModel(
  id: 'tec',
  email: 'tecnico@kym.test',
  role: 'tecnico',
);

void main() {
  late InMemoryKeyValueStore store;
  late StreamController<PasswordRecoveryEvent> recovery;

  _MockAuthDataSource newDataSource() {
    final dataSource = _MockAuthDataSource();
    when(() => dataSource.passwordRecoveryEvents)
        .thenAnswer((_) => recovery.stream);
    when(dataSource.getCurrentUser).thenAnswer((_) async => _tecnico);
    when(dataSource.signOut).thenAnswer((_) async {});
    when(() => dataSource.updatePassword(password: any(named: 'password')))
        .thenAnswer((_) async {});
    return dataSource;
  }

  Future<void> openRecoveryLink(AuthRepositoryImpl repository) async {
    final events = repository.passwordRecoveryEvents.first;
    recovery.add(PasswordRecoveryEvent.started);
    expect(await events, PasswordRecoveryEvent.started);
  }

  setUp(() {
    store = InMemoryKeyValueStore();
    recovery = StreamController<PasswordRecoveryEvent>.broadcast();
  });

  tearDown(() => recovery.close());

  test('fechar o app na tela de nova senha não dá acesso na próxima '
      'abertura', () async {
    await openRecoveryLink(
      AuthRepositoryImpl(newDataSource(), recoveryStore: store),
    );
    expect(await store.read(StorageKeys.passwordRecoveryPending), isNotNull);

    final reopened = newDataSource();
    final repository = AuthRepositoryImpl(reopened, recoveryStore: store);
    final session = SessionController(
      GetCurrentUser(repository),
      SignOut(repository),
    );
    await session.restore();

    expect(session.isAuthenticated, isFalse);
    verify(reopened.signOut).called(1);
    verifyNever(reopened.getCurrentUser);
    expect(await store.read(StorageKeys.passwordRecoveryPending), isNull);
  });

  test('depois de encerrada, a abertura seguinte segue normal', () async {
    await store.write(StorageKeys.passwordRecoveryPending, '1');
    final repository = AuthRepositoryImpl(
      newDataSource(),
      recoveryStore: store,
    );

    expect(await repository.getCurrentUser(), isNull);
    expect((await repository.getCurrentUser())?.id, 'tec');
  });

  test('durante a recuperação o usuário não conta como logado e a sessão '
      'continua aberta para trocar a senha', () async {
    final dataSource = newDataSource();
    final repository = AuthRepositoryImpl(dataSource, recoveryStore: store);
    await openRecoveryLink(repository);

    expect(await repository.getCurrentUser(), isNull);
    verifyNever(dataSource.signOut);
  });

  test(
    'link aberto com o app fechado não é encerrado pela marca antiga',
    () async {
      final slowStore = _SlowKeyValueStore();
      await slowStore.write(StorageKeys.passwordRecoveryPending, '1');
      final dataSource = newDataSource();
      final repository = AuthRepositoryImpl(
        dataSource,
        recoveryStore: slowStore,
      );
      final events = repository.passwordRecoveryEvents.first;

      final restored = repository.getCurrentUser();
      recovery.add(PasswordRecoveryEvent.started);
      await events;
      slowStore.readGate.complete();

      expect(await restored, isNull);
      verifyNever(dataSource.signOut);
    },
  );

  test('salvar a nova senha e sair apaga a marca', () async {
    final dataSource = newDataSource();
    final repository = AuthRepositoryImpl(dataSource, recoveryStore: store);
    await openRecoveryLink(repository);

    await UpdatePassword(repository)(password: 'novaSenha1');

    expect(await store.read(StorageKeys.passwordRecoveryPending), isNull);
    expect((await repository.getCurrentUser())?.id, 'tec');
  });

  test('se a saída falhar depois da troca, a próxima abertura encerra a '
      'sessão', () async {
    final dataSource = newDataSource();
    when(dataSource.signOut)
        .thenThrow(const AuthFailure(AuthFailureType.network));
    final repository = AuthRepositoryImpl(dataSource, recoveryStore: store);
    await openRecoveryLink(repository);

    await UpdatePassword(repository)(password: 'novaSenha1');
    expect(await store.read(StorageKeys.passwordRecoveryPending), isNotNull);

    final reopened = newDataSource();
    final next = AuthRepositoryImpl(reopened, recoveryStore: store);
    expect(await next.getCurrentUser(), isNull);
    verify(reopened.signOut).called(1);
  });

  test('cancelar a nova senha apaga a marca', () async {
    final repository = AuthRepositoryImpl(
      newDataSource(),
      recoveryStore: store,
    );
    await openRecoveryLink(repository);

    await repository.signOut();

    expect(await store.read(StorageKeys.passwordRecoveryPending), isNull);
  });
}
