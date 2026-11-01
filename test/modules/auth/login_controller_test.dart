import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/presenter/controllers/login_controller.dart';
import 'package:kym/modules/auth/domain/usecases/sign_in_with_email.dart';
import 'package:kym/modules/auth/infra/repositories/auth_repository_impl.dart';
import 'package:kym/modules/auth/presenter/utils/auth_failure_message.dart';
import 'package:kym/modules/auth/presenter/utils/login_validators.dart';

void main() {
  late FakeAuthDataSource dataSource;
  late LoginController controller;

  setUp(() {
    dataSource = FakeAuthDataSource(latency: Duration.zero);
    controller = LoginController(
      SignInWithEmail(AuthRepositoryImpl(dataSource)),
    );
  });

  tearDown(() => controller.dispose());

  test('autentica com credenciais válidas', () async {
    await controller.submit(email: ' tecnico@kym.test ', password: 'kym12345');

    expect(controller.status, LoginStatus.success);
    expect(controller.user?.role, UserRole.technician);
    expect(controller.errorMessage, isNull);
  });

  test('mostra erro claro para senha incorreta', () async {
    await controller.submit(email: 'tecnico@kym.test', password: 'errada');

    expect(controller.status, LoginStatus.failure);
    expect(
      controller.errorMessage,
      AuthFailureType.invalidCredentials.userMessage,
    );
    expect(controller.user, isNull);
  });

  test('mostra erro de rede', () async {
    dataSource.nextFailure = AuthFailureType.network;

    await controller.submit(email: 'tecnico@kym.test', password: 'kym12345');

    expect(controller.status, LoginStatus.failure);
    expect(controller.errorMessage, AuthFailureType.network.userMessage);
  });

  test('clearError volta para idle', () async {
    await controller.submit(email: 'x@kym.test', password: 'y');
    controller.clearError();

    expect(controller.status, LoginStatus.idle);
    expect(controller.errorMessage, isNull);
  });

  group('LoginValidators', () {
    test('e-mail', () {
      expect(LoginValidators.email(''), isNotNull);
      expect(LoginValidators.email('abc'), isNotNull);
      expect(LoginValidators.email('a@b.com'), isNull);
    });

    test('senha', () {
      expect(LoginValidators.password(''), isNotNull);
      expect(LoginValidators.password('x'), isNull);
    });
  });
}
