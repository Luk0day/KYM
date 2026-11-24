/// Retorno ao usuário quando um código é detectado (vibração do aparelho).
abstract interface class ScanFeedback {
  Future<void> confirm();
}
