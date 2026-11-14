import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/domain/usecases/send_password_reset_email.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/infra/repositories/auth_repository_impl.dart';

void main() {
  late FakeAuthDataSource dataSource;
  late SendPasswordResetEmail sendPasswordResetEmail;

  setUp(() {
    dataSource = FakeAuthDataSource(latency: Duration.zero);
    sendPasswordResetEmail = SendPasswordResetEmail(
      AuthRepositoryImpl(dataSource),
    );
  });

  test('envia a solicitação com o e-mail sem espaços nas pontas', () async {
    await sendPasswordResetEmail(email: '  tecnico@kym.test  ');

    expect(dataSource.passwordResetRequests, ['tecnico@kym.test']);
  });

  test('propaga a falha do datasource sem registrar a solicitação', () async {
    dataSource.nextFailure = AuthFailureType.rateLimited;

    await expectLater(
      sendPasswordResetEmail(email: 'tecnico@kym.test'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.type,
          'type',
          AuthFailureType.rateLimited,
        ),
      ),
    );
    expect(dataSource.passwordResetRequests, isEmpty);
  });
}
