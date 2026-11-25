import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/app.dart';
import 'package:kym/app/app_module.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/app/database/seed/fake_data_seeder.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';

/// Fluxo real: login -> casca de navegação -> aba Lojas, com o banco do seed
/// em memória. O lojista já começa na aba Lojas; os demais tocam nela.
Future<void> _openStores(
  WidgetTester tester,
  String email, {
  bool tapTab = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  await tester.runAsync(() => FakeDataSeeder(db).seedIfEmpty());

  await tester.pumpWidget(
    ModularApp(
      module: AppModule(
        authDataSourceFactory: () => FakeAuthDataSource(latency: Duration.zero),
        databaseFactory: () => db,
      ),
      child: const KymApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), 'kym12345');
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();

  if (tapTab) {
    await tester.tap(find.text('Lojas'));
    await tester.pumpAndSettle();
  }
}

/// Desmonta o app antes do fim do teste: o Drift agenda um timer ao cancelar
/// os streams, e ele não pode ficar pendente.
Future<void> _closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets('técnico abre a aba Lojas com as lojas do seed', (tester) async {
    await _openStores(tester, 'tecnico@kym.test');

    expect(find.text('Buscar loja'), findsOneWidget);
    expect(find.text('Loja Centro'), findsOneWidget);
    expect(find.text('Loja Boa Viagem'), findsOneWidget);
    expect(find.text('Nenhuma loja atribuída a você'), findsNothing);
    await _closeApp(tester);
  });

  testWidgets('a busca funciona com o banco real', (tester) async {
    await _openStores(tester, 'tecnico@kym.test');

    await tester.enterText(find.byType(TextFormField), 'boa viagem');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Loja Boa Viagem'), findsOneWidget);
    expect(find.text('Loja Centro'), findsNothing);
    await _closeApp(tester);
  });

  testWidgets('lojista já começa na aba Lojas', (tester) async {
    await _openStores(tester, 'lojista@kym.test', tapTab: false);

    expect(find.text('Buscar loja'), findsOneWidget);
    expect(find.text('Loja Centro'), findsOneWidget);
    await _closeApp(tester);
  });
}
