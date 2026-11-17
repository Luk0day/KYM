import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/scanner/domain/services/app_settings_service.dart';
import 'package:kym/modules/scanner/domain/services/scan_feedback.dart';
import 'package:kym/modules/scanner/domain/services/scanned_code_handler.dart';
import 'package:kym/modules/scanner/domain/usecases/open_app_settings.dart';
import 'package:kym/modules/scanner/domain/usecases/process_scanned_code.dart';
import 'package:kym/modules/scanner/presenter/controllers/scanner_controller.dart';
import 'package:mocktail/mocktail.dart';

class _MockFeedback extends Mock implements ScanFeedback {}

class _MockHandler extends Mock implements ScannedCodeHandler {}

class _MockSettings extends Mock implements AppSettingsService {}

void main() {
  late _MockFeedback feedback;
  late _MockHandler handler;
  late _MockSettings settings;
  late ScannerController controller;

  setUp(() {
    feedback = _MockFeedback();
    handler = _MockHandler();
    settings = _MockSettings();
    when(() => feedback.confirm()).thenAnswer((_) async {});
    when(() => handler.handle(any())).thenAnswer((_) async {});
    when(() => settings.open()).thenAnswer((_) async => true);
    controller = ScannerController(
      ProcessScannedCode(feedback, handler),
      OpenAppSettings(settings),
    );
  });

  tearDown(() => controller.dispose());

  test('começa lendo, com a câmera ativa', () {
    expect(controller.status, ScannerStatus.scanning);
    expect(controller.isCameraActive, isTrue);
    expect(controller.lastCode, isNull);
    expect(controller.lastReadFailed, isFalse);
  });

  test('código lido para a câmera e fica tratado', () async {
    final statuses = <ScannerStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.onDetect(' abc ');

    expect(statuses, [ScannerStatus.processing, ScannerStatus.handled]);
    expect(controller.lastCode, 'abc');
    expect(controller.isCameraActive, isFalse);
    verify(() => handler.handle('abc')).called(1);
  });

  test('ignora novas leituras enquanto a anterior é tratada', () async {
    final gate = Completer<void>();
    when(() => handler.handle(any())).thenAnswer((_) => gate.future);

    final first = controller.onDetect('primeiro');
    await controller.onDetect('segundo');

    expect(controller.status, ScannerStatus.processing);
    gate.complete();
    await first;

    verify(() => handler.handle('primeiro')).called(1);
    verifyNever(() => handler.handle('segundo'));
  });

  test('ignora leituras depois de tratada, até voltar a ler', () async {
    await controller.onDetect('abc');
    await controller.onDetect('outro');

    verifyNever(() => handler.handle('outro'));
  });

  test('leitura vazia volta a ler sem marcar erro', () async {
    await controller.onDetect('   ');

    expect(controller.status, ScannerStatus.scanning);
    expect(controller.lastReadFailed, isFalse);
  });

  test('falha no tratamento volta a ler e marca o erro', () async {
    when(() => handler.handle(any())).thenThrow(Exception('servidor'));

    await controller.onDetect('abc');

    expect(controller.status, ScannerStatus.scanning);
    expect(controller.lastReadFailed, isTrue);
    expect(controller.isCameraActive, isTrue);
  });

  test('nova leitura limpa o erro anterior', () async {
    when(() => handler.handle(any())).thenThrow(Exception('servidor'));
    await controller.onDetect('abc');
    when(() => handler.handle(any())).thenAnswer((_) async {});

    await controller.onDetect('abc');

    expect(controller.lastReadFailed, isFalse);
    expect(controller.status, ScannerStatus.handled);
  });

  test('resume volta a ler depois de um código tratado', () async {
    await controller.onDetect('abc');

    controller.resume();

    expect(controller.status, ScannerStatus.scanning);
    expect(controller.lastCode, isNull);
  });

  test('resume sem código tratado não muda nada', () {
    var notified = 0;
    controller.addListener(() => notified++);

    controller.resume();

    expect(notified, 0);
  });

  test('openSettings devolve o resultado do caso de uso', () async {
    expect(await controller.openSettings(), isTrue);

    when(() => settings.open()).thenAnswer((_) async => false);
    expect(await controller.openSettings(), isFalse);
  });

  test('dispose durante o tratamento não notifica depois', () async {
    final gate = Completer<void>();
    when(() => handler.handle(any())).thenAnswer((_) => gate.future);
    final local = ScannerController(
      ProcessScannedCode(feedback, handler),
      OpenAppSettings(settings),
    );

    final pending = local.onDetect('abc');
    local.dispose();
    gate.complete();

    await expectLater(pending, completes);
  });
}
