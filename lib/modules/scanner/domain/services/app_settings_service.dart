/// Abre as configurações do aplicativo no sistema, onde o usuário pode
/// liberar a câmera depois de negá-la.
abstract interface class AppSettingsService {
  /// Devolve false quando o sistema não conseguiu abrir as configurações.
  Future<bool> open();
}
