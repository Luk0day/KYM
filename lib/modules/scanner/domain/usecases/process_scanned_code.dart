import '../entities/scan_outcome.dart';
import '../services/scan_feedback.dart';
import '../services/scanned_code_handler.dart';

/// Recebe o texto de um QR Code detectado, avisa o usuário e o entrega ao
/// tratamento. Nunca lança: o resultado diz se a leitura segue ou não.
class ProcessScannedCode {
  ProcessScannedCode(this._feedback, this._handler);

  final ScanFeedback _feedback;
  final ScannedCodeHandler _handler;

  Future<ScanOutcome> call(String? rawValue) async {
    final code = rawValue?.trim();
    if (code == null || code.isEmpty) return ScanOutcome.ignored;

    // Aparelho sem vibração não pode impedir o tratamento do código.
    try {
      await _feedback.confirm();
    } catch (_) {}

    try {
      await _handler.handle(code);
      return ScanOutcome.handled;
    } catch (_) {
      return ScanOutcome.failed;
    }
  }
}
