import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/app.dart';
import 'package:kym/app/app_module.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/presenter/utils/password_reset_failure_message.dart';

late FakeAuthDataSource dataSource;

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ModularApp(
      module: AppModule(
        authDataSourceFactory: () =>
            dataSource = FakeAuthDataSource(latency: Duration.zero),
      ),
      child: const KymApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openForgotPassword(WidgetTester tester) async {
  await tester.tap(find.text('Esqueci minha senha'));
  await tester.pumpAndSettle();
}

Future<void> _requestLink(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField), email);
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('o login oferece o caminho para recuperar a senha', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _openForgotPassword(tester);

    expect(find.text('Recuperar senha'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets('e-mail válido envia o link e confirma na tela', (tester) async {
    await _pumpApp(tester);
    await _openForgotPassword(tester);

    await _requestLink(tester, 'tecnico@kym.test');

    expect(find.textContaining('enviamos um link'), findsOneWidget);
    expect(find.text('Reenviar link'), findsOneWidget);
    expect(dataSource.passwordResetRequests, ['tecnico@kym.test']);
  });

  testWidgets('e-mail inválido mostra erro no campo e não envia', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openForgotPassword(tester);

    await _requestLink(tester, 'abc');

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(dataSource.passwordResetRequests, isEmpty);
  });

  testWidgets('falha de rede mostra a mensagem de erro na tela', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openForgotPassword(tester);
    dataSource.nextFailure = AuthFailureType.network;

    await _requestLink(tester, 'tecnico@kym.test');

    expect(
      find.text(AuthFailureType.network.passwordResetMessage),
      findsOneWidget,
    );
    expect(find.textContaining('enviamos um link'), findsNothing);
  });

  testWidgets('editar o e-mail depois do envio remove a confirmação', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openForgotPassword(tester);
    await _requestLink(tester, 'tecnico@kym.test');

    await tester.enterText(find.byType(TextFormField), 'outro@kym.test');
    await tester.pump();

    expect(find.textContaining('enviamos um link'), findsNothing);
    expect(find.text('Enviar link'), findsOneWidget);
  });

  testWidgets('a seta de voltar leva de volta ao login', (tester) async {
    await _pumpApp(tester);
    await _openForgotPassword(tester);

    await tester.tap(find.byTooltip('Voltar ao login'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Esqueci minha senha'), findsOneWidget);
  });
}
