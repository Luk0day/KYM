import 'package:flutter/foundation.dart';

import '../../domain/entities/scan_outcome.dart';
import '../../domain/usecases/open_app_settings.dart';
import '../../domain/usecases/process_scanned_code.dart';

enum ScannerStatus {
  /// Câmera lendo.
  scanning,

  /// Um código foi detectado e está sendo tratado; novas leituras são ignoradas.
  processing,

  /// O código foi tratado e a leitura ficou parada.
  handled,
}

class ScannerController extends ChangeNotifier {
  ScannerController(this._processScannedCode, this._openAppSettings);

  final ProcessScannedCode _processScannedCode;
  final OpenAppSettings _openAppSettings;

  ScannerStatus _status = ScannerStatus.scanning;
  String? _lastCode;
  bool _failed = false;
  bool _settingsFailed = false;
  bool _disposed = false;

  ScannerStatus get status => _status;

  /// Último texto tratado com sucesso.
  String? get lastCode => _lastCode;

  /// True quando o último código não pôde ser tratado e a leitura voltou.
  bool get lastReadFailed => _failed;

  /// True quando o sistema não abriu as configurações do aplicativo.
  bool get settingsFailed => _settingsFailed;

  /// A câmera só deve rodar enquanto nenhum código está em tratamento.
  bool get isCameraActive => _status == ScannerStatus.scanning;

  Future<void> onDetect(String? rawValue) async {
    if (_status != ScannerStatus.scanning) return;

    _status = ScannerStatus.processing;
    _failed = false;
    notifyListeners();

    final outcome = await _processScannedCode(rawValue);
    if (_disposed) return;

    switch (outcome) {
      case ScanOutcome.handled:
        _lastCode = rawValue?.trim();
        _status = ScannerStatus.handled;
      case ScanOutcome.ignored:
        _status = ScannerStatus.scanning;
      case ScanOutcome.failed:
        _failed = true;
        _status = ScannerStatus.scanning;
    }
    notifyListeners();
  }

  /// Volta a ler depois de um código tratado.
  void resume() {
    if (_status != ScannerStatus.handled) return;
    _status = ScannerStatus.scanning;
    _lastCode = null;
    _failed = false;
    notifyListeners();
  }

  /// Abre as configurações; se o sistema não abrir, [settingsFailed] avisa.
  Future<bool> openSettings() async {
    final opened = await _openAppSettings();
    if (_disposed) return opened;
    if (_settingsFailed == opened) {
      _settingsFailed = !opened;
      notifyListeners();
    }
    return opened;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
