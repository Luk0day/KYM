/// Tratamento do texto lido: identificar loja ou equipamento e redirecionar
/// (B31 define o formato e B32 faz o redirecionamento).
abstract interface class ScannedCodeHandler {
  Future<void> handle(String code);
}
