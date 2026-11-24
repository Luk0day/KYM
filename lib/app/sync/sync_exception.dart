/// Erros que o envio de uma operação ao servidor pode lançar. A origem
/// (Supabase, rede) é traduzida para um destes dois tipos, porque a fila reage
/// de forma diferente a cada um.
sealed class SyncException implements Exception {
  const SyncException(this.message);

  final String message;
}

/// Falha passageira: sem internet, tempo esgotado, servidor fora do ar ou
/// sessão a renovar. O processamento para e a fila espera a próxima conexão,
/// sem gastar tentativas.
class SyncNetworkException extends SyncException {
  const SyncNetworkException(super.message);

  @override
  String toString() => 'Falha de rede: $message';
}

/// O servidor recusou a operação: RLS, restrição violada, payload inválido.
/// O item é marcado como falho e a fila segue.
class SyncServerException extends SyncException {
  const SyncServerException(super.message, {this.code});

  /// Código do erro (por exemplo o SQLSTATE `42501` de RLS), quando houver.
  final String? code;

  @override
  String toString() =>
      code == null ? 'Erro do servidor: $message' : '[$code] $message';
}
