import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/app.dart';
import 'package:kym/app/app_module.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/presenter/pages/forgot_password_page.dart';
import 'package:kym/modules/auth/presenter/pages/login_page.dart';
import 'package:kym/modules/auth/presenter/pages/reset_password_page.dart';
import 'package:kym/modules/auth/presenter/utils/password_update_failure_message.dart';

late FakeAuthDataSource _dataSource;

Future<void> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  _dataSource = FakeAuthDataSource(latency: Duration.zero);
  await tester.pumpWidget(
    ModularApp(
      module: AppModule(authDataSourceFactory: () => _dataSource),
      child: const KymApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openLink(WidgetTester tester, {bool expired = false}) async {
  _dataSource.simulatePasswordRecoveryLink(
    email: 'tecnico@kym.test',
    expired: expired,
  );
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  required String password,
  String? confirmation,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), password);
  await tester.enterText(
    find.byType(TextFormField).at(1),
    confirmation ?? password,
  );
  await tester.ensureVisible(find.text('Salvar nova senha'));
  await tester.tap(find.text('Salvar nova senha'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('o link do e-mail abre a tela de nova senha', (tester) async {
    await _pumpApp(tester);

    await _openLink(tester);

    expect(find.byType(ResetPasswordPage), findsOneWidget);
    expect(find.text('Defina sua nova senha'), findsOneWidget);
    expect(find.text('Nova senha'), findsWidgets);
    expect(find.text('Confirmar nova senha'), findsOneWidget);
  });

  testWidgets('link que chega durante a abertura do app não é atropelado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    _dataSource = FakeAuthDataSource(
      latency: const Duration(milliseconds: 300),
    );

    await tester.pumpWidget(
      ModularApp(
        module: AppModule(authDataSourceFactory: () => _dataSource),
        child: const KymApp(),
      ),
    );
    _dataSource.simulatePasswordRecoveryLink(email: 'tecnico@kym.test');
    await tester.pumpAndSettle();

    expect(find.byType(ResetPasswordPage), findsOneWidget);
  });

  testWidgets('link com o app já em outra tela abre a nova senha', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordPage), findsOneWidget);

    await _openLink(tester);

    expect(find.byType(ResetPasswordPage), findsOneWidget);
  });

  testWidgets('senha válida troca a senha e leva ao login', (tester) async {
    await _pumpApp(tester);
    await _openLink(tester);

    await _fill(tester, password: 'novaSenha1');

    expect(
      find.text('Senha alterada com sucesso. Entre com a sua nova senha.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ir para o login'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'tecnico@kym.test',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'novaSenha1');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('senha curta e confirmação diferente não são enviadas', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openLink(tester);

    await _fill(tester, password: '123', confirmation: '456');

    expect(find.text('Use pelo menos 6 caracteres.'), findsOneWidget);
    expect(find.text('As senhas não conferem.'), findsOneWidget);
    expect(find.byType(ResetPasswordPage), findsOneWidget);
  });

  testWidgets('senha igual à atual mostra o erro do servidor', (tester) async {
    await _pumpApp(tester);
    await _openLink(tester);

    await _fill(tester, password: 'kym12345');

    expect(
      find.text(AuthFailureType.samePassword.passwordUpdateMessage),
      findsOneWidget,
    );
  });

  testWidgets('sem internet mostra a falta de conexão', (tester) async {
    await _pumpApp(tester);
    await _openLink(tester);
    _dataSource.nextFailure = AuthFailureType.network;

    await _fill(tester, password: 'novaSenha1');

    expect(
      find.text(AuthFailureType.network.passwordUpdateMessage),
      findsOneWidget,
    );
  });

  testWidgets('sessão expirada ao salvar oferece pedir um novo link', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openLink(tester);
    _dataSource.nextFailure = AuthFailureType.recoveryLinkInvalid;

    await _fill(tester, password: 'novaSenha1');

    expect(find.text('Pedir novo link'), findsOneWidget);
    await tester.tap(find.text('Pedir novo link'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
  });

  testWidgets('link expirado leva à recuperação com a orientação', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _openLink(tester, expired: true);

    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(
      find.text(AuthFailureType.recoveryLinkInvalid.passwordUpdateMessage),
      findsOneWidget,
    );
  });

  testWidgets('voltar sem salvar encerra a sessão de recuperação', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openLink(tester);

    await tester.tap(find.byTooltip('Voltar ao login'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(await _dataSource.getCurrentUser(), isNull);
  });

  testWidgets('voltar do sistema também encerra a sessão', (tester) async {
    await _pumpApp(tester);
    await _openLink(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(await _dataSource.getCurrentUser(), isNull);
  });

  testWidgets('mostrar senha alterna a visibilidade', (tester) async {
    await _pumpApp(tester);
    await _openLink(tester);

    bool obscured() => tester
        .widget<EditableText>(find.byType(EditableText).at(0))
        .obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Mostrar nova senha'));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  testWidgets('celular pequeno com fonte em 200% não quebra', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpApp(tester, size: const Size(320, 640));
    await _openLink(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ResetPasswordPage), findsOneWidget);
  });

  testWidgets('segue as diretrizes de acessibilidade', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpApp(tester);
    await _openLink(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
