import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/password_recovery_event.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/domain/repositories/auth_repository.dart';
import 'package:kym/modules/auth/domain/usecases/update_password.dart';
import 'package:kym/modules/auth/domain/usecases/watch_password_recovery.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/infra/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late FakeAuthDataSource dataSource;
  late AuthRepositoryImpl repository;
  late UpdatePassword updatePassword;

  setUp(() {
    dataSource = FakeAuthDataSource(latency: Duration.zero);
    repository = AuthRepositoryImpl(dataSource);
    updatePassword = UpdatePassword(repository);
  });

  group('UpdatePassword', () {
    test('troca a senha, encerra a sessão e a senha nova passa a valer', () async {
      dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');

      await updatePassword(password: 'novaSenha1');

      expect(await repository.getCurrentUser(), isNull);
      final user = await repository.signInWithEmail(
        email: 'tecnico@kym.test',
        password: 'novaSenha1',
      );
      expect(user.email, 'tecnico@kym.test');
    });

    test('a senha antiga deixa de funcionar', () async {
      dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');
      await updatePassword(password: 'novaSenha1');

      expect(
        () => repository.signInWithEmail(
          email: 'tecnico@kym.test',
          password: 'kym12345',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.invalidCredentials,
          ),
        ),
      );
    });

    test('sem sessão de recuperação o link é inválido', () {
      expect(
        () => updatePassword(password: 'novaSenha1'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.recoveryLinkInvalid,
          ),
        ),
      );
    });

    test('senha curta é fraca', () {
      dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');

      expect(
        () => updatePassword(password: '123'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.weakPassword,
          ),
        ),
      );
    });

    test('senha igual à atual é recusada', () {
      dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');

      expect(
        () => updatePassword(password: 'kym12345'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.samePassword,
          ),
        ),
      );
    });

    test('sem internet propaga a falha de rede', () {
      dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');
      dataSource.nextFailure = AuthFailureType.network;

      expect(
        () => updatePassword(password: 'novaSenha1'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.type,
            'type',
            AuthFailureType.network,
          ),
        ),
      );
    });

    test('falha ao sair não desfaz a troca da senha', () async {
      final mock = _MockAuthRepository();
      when(
        () => mock.updatePassword(password: any(named: 'password')),
      ).thenAnswer((_) async {});
      when(mock.signOut).thenThrow(const AuthFailure(AuthFailureType.network));

      await UpdatePassword(mock)(password: 'novaSenha1');

      verify(() => mock.updatePassword(password: 'novaSenha1')).called(1);
      verify(mock.signOut).called(1);
    });
  });

  group('WatchPasswordRecovery', () {
    test('repassa os eventos do link do e-mail', () async {
      final events = <PasswordRecoveryEvent>[];
      final subscription = WatchPasswordRecovery(repository)().listen(
        events.add,
      );

      dataSource.simulatePasswordRecoveryLink(email: 'gestor@kym.test');
      dataSource.simulatePasswordRecoveryLink(
        email: 'gestor@kym.test',
        expired: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, [
        PasswordRecoveryEvent.started,
        PasswordRecoveryEvent.linkInvalid,
      ]);
      await subscription.cancel();
    });

    test('o link válido abre a sessão de recuperação', () async {
      dataSource.simulatePasswordRecoveryLink(email: 'lojista@kym.test');

      final user = await repository.getCurrentUser();

      expect(user?.email, 'lojista@kym.test');
    });
  });
}
