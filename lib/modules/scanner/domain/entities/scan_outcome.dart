/// Resultado do tratamento de um código lido pela câmera.
enum ScanOutcome {
  /// O texto foi aceito e entregue ao tratamento (B32).
  handled,

  /// Leitura vazia: não há nada a tratar e a câmera pode continuar.
  ignored,

  /// O tratamento falhou; a câmera volta a ler para uma nova tentativa.
  failed,
}
