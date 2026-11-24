import '../services/app_settings_service.dart';

class OpenAppSettings {
  OpenAppSettings(this._service);

  final AppSettingsService _service;

  /// Devolve false quando as configurações não abriram, inclusive por erro.
  Future<bool> call() async {
    try {
      return await _service.open();
    } catch (_) {
      return false;
    }
  }
}
