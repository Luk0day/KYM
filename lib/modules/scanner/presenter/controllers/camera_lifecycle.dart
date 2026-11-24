/// Decide quando a câmera para e quando volta ao trocar de primeiro e segundo
/// plano. Fica fora do widget para ser testado sem a câmera.
class CameraLifecycle {
  bool _resumeOnForeground = false;
  bool _awaitingSettings = false;

  /// O usuário foi mandado às configurações: ao voltar, tenta iniciar de novo.
  void markAwaitingSettings() => _awaitingSettings = true;

  /// App foi para segundo plano. Devolve true quando a câmera deve parar.
  /// Câmera que ainda não iniciou (diálogo de permissão aberto) não é parada
  /// nem religada depois.
  bool onBackground({required bool isRunning}) {
    if (!isRunning) return false;
    _resumeOnForeground = true;
    return true;
  }

  /// App voltou ao primeiro plano. Devolve true quando a câmera deve iniciar.
  bool onForeground({required bool active}) {
    final shouldStart = _resumeOnForeground || _awaitingSettings;
    _resumeOnForeground = false;
    _awaitingSettings = false;
    return shouldStart && active;
  }
}
