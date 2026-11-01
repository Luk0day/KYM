import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/app.dart';
import 'package:kym/app/app_module.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/presenter/utils/auth_failure_message.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';

Future<void> _pumpApp(WidgetTester tester) async {
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
      email: 'gerente@kym.test',
      password: 'kym12345',
    );

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
