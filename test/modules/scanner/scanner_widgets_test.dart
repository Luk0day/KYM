import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/theme/app_theme.dart';
import 'package:kym/modules/scanner/domain/services/app_settings_service.dart';
import 'package:kym/modules/scanner/domain/services/scan_feedback.dart';
import 'package:kym/modules/scanner/domain/services/scanned_code_handler.dart';
import 'package:kym/modules/scanner/domain/usecases/open_app_settings.dart';
import 'package:kym/modules/scanner/domain/usecases/process_scanned_code.dart';
import 'package:kym/modules/scanner/presenter/controllers/scanner_controller.dart';
import 'package:kym/modules/scanner/presenter/pages/scanner_page.dart';
import 'package:kym/modules/scanner/presenter/widgets/scanner_permission_denied.dart';
import 'package:kym/modules/scanner/presenter/widgets/scanner_unavailable.dart';
import 'package:mocktail/mocktail.dart';

class _MockFeedback extends Mock implements ScanFeedback {}

class _MockHandler extends Mock implements ScannedCodeHandler {}

class _MockSettings extends Mock implements AppSettingsService {}

Future<void> _expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Widget _darkScaffold(Widget child) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(backgroundColor: const Color(0xFF1C1F36), body: child),
);

void main() {
  group('estado de permissão negada', () {
    testWidgets('explica o motivo e oferece Abrir configurações', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _darkScaffold(ScannerPermissionDenied(onOpenSettings: () => taps++)),
      );

      expect(find.text('Precisamos da câmera'), findsOneWidget);
      expect(find.textContaining('ler o QR Code'), findsOneWidget);

      await tester.tap(find.text('Abrir configurações'));

      expect(taps, 1);
    });

    testWidgets('atende às guidelines de acessibilidade', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _darkScaffold(ScannerPermissionDenied(onOpenSettings: () {})),
      );

      await _expectAccessible(tester);
      handle.dispose();
    });

    testWidgets('não quebra com fonte a 200% em tela pequena', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2),
          ),
          child: _darkScaffold(ScannerPermissionDenied(onOpenSettings: () {})),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('estado de câmera indisponível', () {
    testWidgets('explica que a câmera não está disponível', (tester) async {
      await tester.pumpWidget(_darkScaffold(const ScannerUnavailable()));

      expect(find.text('Câmera indisponível'), findsOneWidget);
      expect(find.textContaining('emulador'), findsOneWidget);
    });
  });

  group('ScannerPage', () {
    late _MockHandler handler;
    late ScannerController controller;
    late void Function(String) detect;

    setUp(() {
      final feedback = _MockFeedback();
      handler = _MockHandler();
      final settings = _MockSettings();
      when(() => feedback.confirm()).thenAnswer((_) async {});
      when(() => handler.handle(any())).thenAnswer((_) async {});
      when(() => settings.open()).thenAnswer((_) async => true);
      controller = ScannerController(
        ProcessScannedCode(feedback, handler),
        OpenAppSettings(settings),
      );
    });

    tearDown(() => controller.dispose());

    Future<void> pumpPage(
      WidgetTester tester, {
      required bool showStoreLegend,
      VoidCallback? onBack,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ScannerPage(
            controller: controller,
            showStoreLegend: showStoreLegend,
            onBack: onBack ?? () {},
            cameraBuilder:
                (
                  context, {
                  required active,
                  required onDetect,
                  required onOpenSettings,
                }) {
                  detect = onDetect;
                  return Center(
                    child: Text(
                      active ? 'camera ativa' : 'camera parada',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
          ),
        ),
      );
    }

    testWidgets('técnico vê as duas legendas', (tester) async {
      await pumpPage(tester, showStoreLegend: true);

      expect(find.text('Leitor de QR Code'), findsOneWidget);
      expect(
        find.text('QR da loja → check-in / check-out'),
        findsOneWidget,
      );
      expect(
        find.text('QR do equipamento → abre os detalhes'),
        findsOneWidget,
      );
    });

    testWidgets('lojista vê só a legenda do equipamento', (tester) async {
      await pumpPage(tester, showStoreLegend: false);

      expect(find.textContaining('QR da loja'), findsNothing);
      expect(
        find.text('QR do equipamento → abre os detalhes'),
        findsOneWidget,
      );
    });

    testWidgets('Voltar chama onBack', (tester) async {
      var back = 0;
      await pumpPage(tester, showStoreLegend: true, onBack: () => back++);

      await tester.tap(find.byTooltip('Voltar'));

      expect(back, 1);
    });

    testWidgets('ler um código para a câmera e mostra o texto lido', (
      tester,
    ) async {
      await pumpPage(tester, showStoreLegend: true);
      expect(find.text('camera ativa'), findsOneWidget);

      detect('KYM-EQ-9');
      await tester.pumpAndSettle();

      expect(find.text('camera parada'), findsOneWidget);
      expect(find.text('Código lido'), findsOneWidget);
      expect(find.text('KYM-EQ-9'), findsOneWidget);

      await tester.tap(find.text('Ler outro código'));
      await tester.pumpAndSettle();

      expect(find.text('camera ativa'), findsOneWidget);
      expect(find.text('Código lido'), findsNothing);
    });

    testWidgets('falha no tratamento mostra aviso e mantém a leitura', (
      tester,
    ) async {
      when(() => handler.handle(any())).thenThrow(Exception('servidor'));
      await pumpPage(tester, showStoreLegend: true);

      detect('KYM-EQ-9');
      await tester.pumpAndSettle();

      expect(find.textContaining('Não foi possível tratar'), findsOneWidget);
      expect(find.text('camera ativa'), findsOneWidget);
    });

    testWidgets('atende às guidelines de acessibilidade', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, showStoreLegend: true);

      await _expectAccessible(tester);
      handle.dispose();
    });

    testWidgets('cabe em paisagem e com fonte a 200%', (tester) async {
      tester.view.physicalSize = const Size(640, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(640, 320),
            textScaler: TextScaler.linear(2),
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: ScannerPage(
              controller: controller,
              showStoreLegend: true,
              onBack: () {},
              cameraBuilder:
                  (
                    context, {
                    required active,
                    required onDetect,
                    required onOpenSettings,
                  }) => const SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
