import '../../domain/services/scanned_code_handler.dart';

/// Tratamento provisório até a B32: aceita o texto sem redirecionar.
/// A B32 troca o registro de [ScannedCodeHandler] no ScannerModule.
class PendingScannedCodeHandler implements ScannedCodeHandler {
  @override
  Future<void> handle(String code) async {}
}
