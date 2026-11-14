import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/domain/usecases/send_password_reset_email.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/infra/repositories/auth_repository_impl.dart';
import 'package:kym/modules/auth/presenter/controllers/forgot_password_controller.dart';
import 'package:kym/modules/auth/presenter/utils/password_reset_failure_message.dart';

void main() {
  late FakeAuthDataSource dataSource;
  late ForgotPasswordController controller;

  ForgotPasswordController newController() {
    return ForgotPasswordController(
      SendPasswordResetEmail(AuthRepositoryImpl(dataSource)),
    );
  }

  setUp(() {
    dataSource = FakeAuthDataSource(latency: Duration.zero);
    controller = newController();
  });

  tearDown(() => controller.dispose());

  test('começa ocioso e sem mensagens', () {
    expect(controller.status, ForgotPasswordStatus.idle);
    expect(controller.errorMessage, isNull);
    expect(controller.requestedEmail, isNull);
    expect(controller.isLoading, isFalse);
  });

  test('solicita o link e termina em sucesso', () async {
    await controller.submit(email: ' tecnico@kym.test ');

    expect(controller.status, ForgotPasswordStatus.success);
    expect(controller.requestedEmail, 'tecnico@kym.test');
    expect(controller.errorMessage, isNull);
    expect(dataSource.passwordResetRequests, ['tecnico@kym.test']);
  });

  test('e-mail não cadastrado também termina em sucesso', () async {
    await controller.submit(email: 'ninguem@kym.test');

    expect(controller.status, ForgotPasswordStatus.success);
    expect(controller.errorMessage, isNull);
  });

  test('passa por carregamento antes do resultado', () async {
    final statuses = <ForgotPasswordStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.submit(email: 'tecnico@kym.test');

    expect(statuses, [
      ForgotPasswordStatus.loading,
      ForgotPasswordStatus.success,
    ]);
  });

  test('mostra erro de rede com a mensagem de recuperação', () async {
    dataSource.nextFailure = AuthFailureType.network;

    await controller.submit(email: 'tecnico@kym.test');

    expect(controller.status, ForgotPasswordStatus.failure);
    expect(
      controller.errorMessage,
      AuthFailureType.network.passwordResetMessage,
    );
    expect(controller.requestedEmail, isNull);
  });

  test('mostra a orientação de espera quando o limite é atingido', () async {
    dataSource.nextFailure = AuthFailureType.rateLimited;

    await controller.submit(email: 'tecnico@kym.test');

    expect(controller.status, ForgotPasswordStatus.failure);
    expect(
      controller.errorMessage,
      AuthFailureType.rateLimited.passwordResetMessage,
    );
  });

  test('falha inesperada vira mensagem genérica de recuperação', () async {
    dataSource.nextFailure = AuthFailureType.unexpected;

    await controller.submit(email: 'tecnico@kym.test');

    expect(controller.status, ForgotPasswordStatus.failure);
    expect(
      controller.errorMessage,
      AuthFailureType.unexpected.passwordResetMessage,
    );
  });

  test('ignora novo envio enquanto outro está em andamento', () async {
    final first = controller.submit(email: 'primeiro@kym.test');
    final second = controller.submit(email: 'segundo@kym.test');

    await Future.wait([first, second]);

    expect(dataSource.passwordResetRequests, ['primeiro@kym.test']);
  });

  test('clearFeedback limpa a mensagem de erro', () async {
    dataSource.nextFailure = AuthFailureType.network;
    await controller.submit(email: 'tecnico@kym.test');

    controller.clearFeedback();

    expect(controller.status, ForgotPasswordStatus.idle);
    expect(controller.errorMessage, isNull);
  });

  test('clearFeedback limpa a confirmação de sucesso', () async {
    await controller.submit(email: 'tecnico@kym.test');

    controller.clearFeedback();

    expect(controller.status, ForgotPasswordStatus.idle);
    expect(controller.requestedEmail, isNull);
  });

  test('não notifica depois de descartado', () async {
    final disposable = newController();

    final pending = disposable.submit(email: 'tecnico@kym.test');
    disposable.dispose();

    await expectLater(pending, completes);
  });
}
