import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/password_recovery_event.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/domain/usecases/sign_out.dart';
import 'package:kym/modules/auth/domain/usecases/update_password.dart';
import 'package:kym/modules/auth/domain/usecases/watch_password_recovery.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/infra/repositories/auth_repository_impl.dart';
import 'package:kym/modules/auth/presenter/controllers/password_recovery_controller.dart';
import 'package:kym/modules/auth/presenter/controllers/reset_password_controller.dart';
import 'package:kym/modules/auth/presenter/utils/password_update_failure_message.dart';

void main() {
  late FakeAuthDataSource dataSource;
  late AuthRepositoryImpl repository;

  setUp(() {
    dataSource = FakeAuthDataSource(latency: Duration.zero);
    repository = AuthRepositoryImpl(dataSource);
  });

  group('ResetPasswordController', () {
    late ResetPasswordController controller;

    setUp(() {
      controller = ResetPasswordController(
        UpdatePassword(repository),
        SignOut(repository),
      );
      dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');
    });

    tearDown(() => controller.dispose());

    test('começa parado', () {
      expect(controller.status, ResetPasswordStatus.idle);
      expect(controller.errorMessage, isNull);
    });

    test('passa por carregando e termina em sucesso', () async {
      final statuses = <ResetPasswordStatus>[];
      controller.addListener(() => statuses.add(controller.status));

      await controller.submit(password: 'novaSenha1');

      expect(statuses, [
        ResetPasswordStatus.loading,
        ResetPasswordStatus.success,
      ]);
      expect(await repository.getCurrentUser(), isNull);
    });

    test('senha igual à atual mostra a mensagem certa', () async {
      await controller.submit(password: 'kym12345');

      expect(controller.status, ResetPasswordStatus.failure);
      expect(
        controller.errorMessage,
        AuthFailureType.samePassword.passwordUpdateMessage,
      );
      expect(controller.isLinkInvalid, isFalse);
    });

    test('link expirado sinaliza para pedir um novo link', () async {
      dataSource.nextFailure = AuthFailureType.recoveryLinkInvalid;

      await controller.submit(password: 'novaSenha1');

      expect(controller.isLinkInvalid, isTrue);
      expect(controller.errorMessage, contains('novo link'));
    });

    test('sem internet mostra a falta de conexão', () async {
      dataSource.nextFailure = AuthFailureType.network;

      await controller.submit(password: 'novaSenha1');

      expect(controller.errorMessage, contains('internet'));
    });

    test('ignora um segundo envio enquanto carrega', () async {
      final first = controller.submit(password: 'novaSenha1');
      final second = controller.submit(password: 'outraSenha2');
      await Future.wait([first, second]);

      expect(controller.status, ResetPasswordStatus.success);
      await repository.signInWithEmail(
        email: 'tecnico@kym.test',
        password: 'novaSenha1',
      );
    });

    test('clearFeedback volta para parado depois de uma falha', () async {
      await controller.submit(password: 'kym12345');

      controller.clearFeedback();

      expect(controller.status, ResetPasswordStatus.idle);
      expect(controller.errorMessage, isNull);
    });

    test('cancelar encerra a sessão de recuperação', () async {
      await controller.cancel();

      expect(await repository.getCurrentUser(), isNull);
    });

    test('não notifica depois de descartado', () async {
      final disposable = ResetPasswordController(
        UpdatePassword(repository),
        SignOut(repository),
      );
      final pending = disposable.submit(password: 'novaSenha1');
      disposable.dispose();

      await pending;
    });
  });

  group('PasswordRecoveryController', () {
    late PasswordRecoveryController controller;

    setUp(() {
      controller = PasswordRecoveryController(
        WatchPasswordRecovery(repository),
      )..start();
    });

    tearDown(() => controller.dispose());

    test('guarda o link aberto até a interface consumir', () async {
      dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');
      await Future<void>.delayed(Duration.zero);

      expect(controller.isRecovering, isTrue);
      expect(controller.consume(), PasswordRecoveryEvent.started);
      expect(controller.pending, isNull);
      expect(controller.isRecovering, isFalse);
    });

    test('link expirado fica pendente como inválido', () async {
      dataSource.simulatePasswordRecoveryLink(
        email: 'tecnico@kym.test',
        expired: true,
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.pending, PasswordRecoveryEvent.linkInvalid);
      expect(controller.isRecovering, isFalse);
    });

    test('start chamado de novo não duplica a escuta', () async {
      var notifications = 0;
      controller
        ..addListener(() => notifications++)
        ..start();

      dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');
      await Future<void>.delayed(Duration.zero);

      expect(notifications, 1);
    });
  });
}
