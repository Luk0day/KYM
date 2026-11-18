/// Como a operação é aplicada no servidor.
enum RemoteOperationKind {
  /// Inserção idempotente: se o id já existe, nada muda. Reenviar o mesmo item
  /// não duplica o registro.
  insert,

  /// Atualiza as colunas do payload na linha com o id.
  update,

  /// Apaga a linha com o id. Apagar o que já não existe não é erro.
  delete,
}

/// Uma operação da outbox já traduzida para o formato do servidor.
class RemoteOperation {
  const RemoteOperation({
    required this.kind,
    required this.table,
    required this.id,
    required this.data,
  });

  final RemoteOperationKind kind;

  /// Tabela do Postgres (`stores`, `equipment`, `maintenance_orders`…).
  final String table;

  /// Id (uuid) do registro.
  final String id;

  /// Colunas em `snake_case`, com os valores já no formato do Postgres.
  final Map<String, Object?> data;

  @override
  String toString() => 'RemoteOperation(${kind.name} $table/$id)';
}

/// Onde a baixada de uma tabela parou: as linhas vêm ordenadas por
/// (`updated_at`, `id`) e a próxima página começa depois deste ponto.
class PullCursor {
  const PullCursor({required this.updatedAt, this.id});

  /// `updated_at` em ISO 8601 UTC, como o servidor mandou.
  final String updatedAt;

  /// Id da última linha recebida. Sem ele, a página começa em [updatedAt]
  /// inclusive (`>=`), o que pode repetir linhas, mas nunca pula nenhuma.
  final String? id;

  @override
  String toString() => 'PullCursor($updatedAt, $id)';
}

/// Envio e baixada de dados do servidor. A implementação real usa o Supabase
/// (external); os testes usam um fake.
abstract class RemoteSyncDataSource {
  /// Se há usuário logado. Sem sessão o RLS recusaria tudo, então a fila nem
  /// começa.
  Future<bool> hasSession();

  /// Emite quando passa a existir uma sessão válida (app aberto já logado,
  /// login, token renovado). É um dos gatilhos da sincronização.
  Stream<void> get sessionReady;

  /// Aplica a operação. Lança `SyncNetworkException` em falha passageira e
  /// `SyncServerException` quando o servidor recusa.
  Future<void> push(RemoteOperation operation);

  /// Uma página de linhas de [table] que o usuário pode ver (a RLS filtra),
  /// ordenadas por (`updated_at`, `id`) e a partir de [after]. Sem [after],
  /// desde o início. Lança as mesmas exceções de [push].
  Future<List<Map<String, dynamic>>> fetchChanges(
    String table, {
    PullCursor? after,
    required int limit,
  });
}
