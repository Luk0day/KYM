import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/app.dart';
import 'package:kym/app/app_module.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/home/home_routes.dart';
import 'package:kym/modules/home/presenter/pages/qr_scanner_placeholder_page.dart';
import 'package:kym/modules/home/presenter/pages/shell_page.dart';
import 'package:kym/shared/presenter/widgets/kym_bottom_nav_bar.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ModularApp(
      module: AppModule(
        authDataSourceFactory: () => FakeAuthDataSource(latency: Duration.zero),
      ),
      child: const KymApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), 'kym12345');
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

Future<void> _signOut(WidgetTester tester) async {
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sair da conta'));
  await tester.pumpAndSettle();
}

List<String> _barLabels(WidgetTester tester) {
  final bar = tester.widget<KymBottomNavBar>(find.byType(KymBottomNavBar));
  return [for (final item in bar.items) item.label];
}

void _navigateFromRoot(WidgetTester tester, String path) {
  tester.element(find.byType(ShellPage)).navigate(path);
}

void main() {
  group('barra por perfil', () {
    testWidgets('técnico: Painel, Lojas, Escanear, Agenda e Perfil', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _signIn(tester, 'tecnico@kym.test');

      expect(_barLabels(tester), [
        'Painel',
        'Lojas',
        'Escanear',
        'Agenda',
        'Perfil',
      ]);
      expect(find.text('Olá, Técnico'), findsOneWidget);
      expect(find.text('Técnico'), findsWidgets);
    });

    testWidgets('gestor: Painel, Lojas, Agenda, QR Codes e Perfil', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _signIn(tester, 'gestor@kym.test');

      expect(_barLabels(tester), [
        'Painel',
        'Lojas',
        'Agenda',
        'QR Codes',
        'Perfil',
      ]);
      expect(find.text('Escanear'), findsNothing);
      expect(find.text('Olá, Gestor'), findsOneWidget);
    });

    testWidgets('lojista: Lojas, Escanear e Perfil, abrindo em Lojas', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _signIn(tester, 'lojista@kym.test');

      expect(_barLabels(tester), ['Lojas', 'Escanear', 'Perfil']);
      expect(find.text('Painel'), findsNothing);
      expect(find.text('Agenda'), findsNothing);
      expect(find.text('Lojas'), findsNWidgets(2));
    });
  });

  group('navegação', () {
    testWidgets('trocar de aba mantém a barra e mostra a nova tela', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _signIn(tester, 'tecnico@kym.test');

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();

      expect(find.byType(KymBottomNavBar), findsOneWidget);
      expect(find.text('Agenda'), findsNWidgets(2));
      final bar = tester.widget<KymBottomNavBar>(find.byType(KymBottomNavBar));
      expect(bar.selectedIndex, 3);
    });

    testWidgets('botão central abre o leitor em tela cheia e volta', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _signIn(tester, 'tecnico@kym.test');

      await tester.tap(find.byTooltip('Escanear QR Code'));
      await tester.pumpAndSettle();

      expect(find.byType(QrScannerPlaceholderPage), findsOneWidget);
      expect(find.text('Leitor de QR Code'), findsOneWidget);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(QrScannerPlaceholderPage), findsNothing);
      expect(find.text('Olá, Técnico'), findsOneWidget);
    });

    testWidgets('sair e entrar com outro perfil troca a barra', (tester) async {
      await _pumpApp(tester);
      await _signIn(tester, 'tecnico@kym.test');
      await _signOut(tester);

      expect(find.byType(TextFormField), findsNWidgets(2));

      await _signIn(tester, 'lojista@kym.test');

      expect(_barLabels(tester), ['Lojas', 'Escanear', 'Perfil']);
    });
  });

  group('guards', () {
    testWidgets('técnico na rota de QR Codes volta para o Painel', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _signIn(tester, 'tecnico@kym.test');
      await tester.tap(find.text('Lojas'));
      await tester.pumpAndSettle();

      _navigateFromRoot(tester, HomeRoutes.qrCodes);
      await tester.pumpAndSettle();

      expect(find.text('QR Codes'), findsNothing);
      expect(find.text('Olá, Técnico'), findsOneWidget);
    });

    testWidgets('gestor não abre o leitor de QR', (tester) async {
      await _pumpApp(tester);
      await _signIn(tester, 'gestor@kym.test');

      _navigateFromRoot(tester, HomeRoutes.qr);
      await tester.pumpAndSettle();

      expect(find.byType(QrScannerPlaceholderPage), findsNothing);
      expect(find.text('Olá, Gestor'), findsOneWidget);
    });

    testWidgets('lojista na Agenda volta para Lojas', (tester) async {
      await _pumpApp(tester);
      await _signIn(tester, 'lojista@kym.test');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      _navigateFromRoot(tester, HomeRoutes.agenda);
      await tester.pumpAndSettle();

      expect(find.text('Lojas'), findsNWidgets(2));
      expect(find.text('Agenda'), findsNothing);
    });

    testWidgets('/home abre a aba inicial do perfil', (tester) async {
      await _pumpApp(tester);
      await _signIn(tester, 'gestor@kym.test');
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();

      _navigateFromRoot(tester, HomeRoutes.root);
      await tester.pumpAndSettle();

      expect(find.text('Olá, Gestor'), findsOneWidget);
    });
  });

  group('layout e acessibilidade', () {
    testWidgets('tela larga usa NavigationRail com os mesmos destinos', (
      tester,
    ) async {
      await _pumpApp(tester, size: const Size(1024, 768));
      await _signIn(tester, 'tecnico@kym.test');

      expect(find.byType(KymBottomNavBar), findsNothing);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.destinations, hasLength(5));
      expect(rail.selectedIndex, 0);

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        3,
      );
    });

    testWidgets('girar a tela mantém a aba atual', (tester) async {
      await _pumpApp(tester);
      await _signIn(tester, 'tecnico@kym.test');
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Agenda'), findsNWidgets(2));
    });

    testWidgets('celular pequeno com fonte em 200% não quebra a barra', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await _pumpApp(tester, size: const Size(320, 640));
      await _signIn(tester, 'tecnico@kym.test');

      expect(tester.takeException(), isNull);
      expect(find.byType(KymBottomNavBar), findsOneWidget);
    });

    testWidgets('barra segue as diretrizes de acessibilidade', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpApp(tester);
      await _signIn(tester, 'tecnico@kym.test');

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
