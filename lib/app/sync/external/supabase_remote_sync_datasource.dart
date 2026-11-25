import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../infra/remote_sync_datasource.dart';
import '../sync_exception.dart';

class SupabaseRemoteSyncDataSource implements RemoteSyncDataSource {
  SupabaseRemoteSyncDataSource(
    this._client, {
    this.timeout = const Duration(seconds: 20),
  });

  final SupabaseClient _client;

  /// Sem resposta nesse tempo, a operação conta como falha de rede.
  final Duration timeout;

  static const _sessionEvents = {
    AuthChangeEvent.initialSession,
    AuthChangeEvent.signedIn,
    AuthChangeEvent.tokenRefreshed,
  };

  @override
  Future<String?> currentUserId() async =>
      _client.auth.currentSession?.user.id;

  @override
  Stream<void> get sessionReady => _client.auth.onAuthStateChange
      .where((s) => s.session != null && _sessionEvents.contains(s.event))
      .map((_) {});

  @override
  Future<void> push(RemoteOperation operation) async {
    try {
      await _send(operation).timeout(timeout);
    } on SyncException {
      rethrow;
    } catch (error) {
      throw classifySyncError(error);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchChanges(
    String table, {
    PullCursor? after,
    required int limit,
  }) async {
    try {
      return await _fetch(table, after, limit).timeout(timeout);
    } catch (error) {
      throw classifySyncError(error);
    }
  }

  Future<List<Map<String, dynamic>>> _fetch(
    String table,
    PullCursor? after,
    int limit,
  ) {
    var query = _client.from(table).select();
    if (after != null) {
      final id = after.id;
      if (id == null) {
        query = query.gte('updated_at', after.updatedAt);
      } else {
        // Paginação por chave (keyset): depois de (updated_at, id). Com
        // offset, uma linha alterada no meio da baixada mudaria de posição e
        // outra seria pulada. O valor vai entre aspas porque tem `:` e `.`,
        // que são separadores no filtro `or` do PostgREST.
        final at = '"${after.updatedAt}"';
        query = query.or(
          'updated_at.gt.$at,and(updated_at.eq.$at,id.gt.$id)',
        );
      }
    }
    return query
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);
  }

  Future<void> _send(RemoteOperation op) async {
    final table = _client.from(op.table);
    switch (op.kind) {
      case RemoteOperationKind.insert:
        // ON CONFLICT DO NOTHING: reenviar não duplica e não exige permissão
        // de UPDATE (o lojista, por exemplo, só insere chamados).
        await table.upsert(op.data, onConflict: 'id', ignoreDuplicates: true);
      case RemoteOperationKind.update:
        final changes = Map.of(op.data)..remove('id');
        if (changes.isEmpty) return;
        // O RLS não dá erro numa atualização bloqueada: só não altera nada.
        // Pedir a linha de volta é o jeito de perceber isso.
        final rows = await table.update(changes).eq('id', op.id).select('id');
        if (rows.isEmpty) {
          throw SyncServerException(
            'nenhuma linha de ${op.table} foi atualizada (registro '
            'inexistente ou sem permissão)',
            code: 'no_rows',
          );
        }
      case RemoteOperationKind.delete:
        await table.delete().eq('id', op.id);
    }
  }
}

/// Traduz um erro do Supabase ou da rede para [SyncNetworkException]
/// (passageiro: a fila para e espera) ou [SyncServerException] (o servidor
/// recusou: o item falha e a fila segue).
SyncException classifySyncError(Object error) {
  return switch (error) {
    SyncException() => error,
    SocketException() ||
    TimeoutException() ||
    HttpException() ||
    HandshakeException() ||
    http.ClientException() =>
      SyncNetworkException(error.toString()),
    // Sessão expirada com o app muito tempo offline: o supabase_flutter
    // renova ao reconectar, então vale tentar de novo depois.
    AuthException(:final message) => SyncNetworkException(message),
    PostgrestException(:final code, :final message) => _isTransient(code)
        ? SyncNetworkException(message)
        : SyncServerException(message, code: code),
    _ => SyncServerException(error.toString()),
  };
}

/// Códigos de erro que não dependem do conteúdo da operação: JWT expirado,
/// HTTP 401/408/429/5xx e SQLSTATE de conexão, recursos ou concorrência.
bool _isTransient(String? code) {
  if (code == null) return false;
  if (const {'PGRST301', 'PGRST302', 'PGRST303', '401', '408', '429'}
      .contains(code)) {
    return true;
  }
  if (RegExp(r'^5\d\d$').hasMatch(code)) return true;
  if (code == '40001' || code == '40P01') return true;
  return code.startsWith('08') ||
      code.startsWith('53') ||
      code.startsWith('57');
}
