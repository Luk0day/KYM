import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/scanner/domain/entities/scan_outcome.dart';
import 'package:kym/modules/scanner/domain/services/scan_feedback.dart';
import 'package:kym/modules/scanner/domain/services/scanned_code_handler.dart';
import 'package:kym/modules/scanner/domain/usecases/process_scanned_code.dart';
import 'package:mocktail/mocktail.dart';

class _MockFeedback extends Mock implements ScanFeedback {}

class _MockHandler extends Mock implements ScannedCodeHandler {}

void main() {
  late _MockFeedback feedback;
  late _MockHandler handler;
  late ProcessScannedCode useCase;

  setUp(() {
    feedback = _MockFeedback();
    handler = _MockHandler();
    when(() => feedback.confirm()).thenAnswer((_) async {});
    when(() => handler.handle(any())).thenAnswer((_) async {});
    useCase = ProcessScannedCode(feedback, handler);
  });

  test('vibra e entrega o texto sem espaços nas pontas ao tratamento', () async {
    final outcome = await useCase('  KYM-LOJA-1  ');

    expect(outcome, ScanOutcome.handled);
    verify(() => feedback.confirm()).called(1);
    verify(() => handler.handle('KYM-LOJA-1')).called(1);
  });

  test('leitura nula ou vazia é ignorada sem vibrar nem tratar', () async {
    for (final raw in [null, '', '   ']) {
      expect(await useCase(raw), ScanOutcome.ignored, reason: '$raw');
    }

    verifyNever(() => feedback.confirm());
    verifyNever(() => handler.handle(any()));
  });

  test('falha no tratamento vira failed', () async {
    when(() => handler.handle(any())).thenThrow(Exception('servidor'));

    expect(await useCase('abc'), ScanOutcome.failed);
  });

  test('falha da vibração não impede o tratamento', () async {
    when(() => feedback.confirm()).thenThrow(Exception('sem vibração'));

    expect(await useCase('abc'), ScanOutcome.handled);
    verify(() => handler.handle('abc')).called(1);
  });
}
