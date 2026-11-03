import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/app.dart';
import 'package:kym/app/app_module.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/presenter/utils/auth_failure_message.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ModularApp(
      module: AppModule(
        authDataSourceFactory: () =>
            FakeAuthDataSource(latency: Duration.zero),
      ),
      child: const KymApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAndSubmit(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sem sessão, a splash leva ao login', (tester) async {
    await _pumpApp(tester);

    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('login mostra os elementos do design', (tester) async {
    await _pumpApp(tester);

    expect(find.text('KYM'), findsOneWidget);
    expect(find.text('Know Your Maintenance'), findsOneWidget);
    expect(find.text('Entrar'), findsNWidgets(2));
    expect(find.text('Acesse com sua conta para continuar'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(
      find.text('Funciona offline · seus dados ficam sincronizados'),
      findsOneWidget,
    );
  });

  testWidgets('campos vazios mostram erro de validação', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
  });

  testWidgets('botão de olho mostra e oculta a senha', (tester) async {
    await _pumpApp(tester);

    bool isObscured() =>
        tester.widget<EditableText>(find.byType(EditableText).at(1)).obscureText;

    expect(isObscured(), isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off_rounded));
    await tester.pump();

    expect(isObscured(), isFalse);
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
  });

  testWidgets('continuar com Google leva à área autenticada', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Continuar com Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Olá, Técnico Teste'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('recuperação de senha avisa que vem em breve', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pump();
    expect(find.text('Recuperação de senha em breve.'), findsOneWidget);
  });

  testWidgets('login válido leva à área autenticada', (tester) async {
    await _pumpApp(tester);

    await _fillAndSubmit(
      tester,
      email: 'tecnico@kym.test',
      password: 'kym12345',
    );

    expect(find.textContaining('Olá, Técnico Teste'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('credenciais inválidas mostram erro e ficam no login',
      (tester) async {
    await _pumpApp(tester);

    await _fillAndSubmit(
      tester,
      email: 'tecnico@kym.test',
      password: 'errada',
    );

    expect(
      find.text(AuthFailureType.invalidCredentials.userMessage),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('sair volta para o login', (tester) async {
    await _pumpApp(tester);
    await _fillAndSubmit(
      tester,
      email: 'gestor@kym.test',
      password: 'kym12345',
    );

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
