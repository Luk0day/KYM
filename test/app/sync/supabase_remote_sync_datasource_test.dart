import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kym/app/sync/external/supabase_remote_sync_datasource.dart';
import 'package:kym/app/sync/infra/remote_sync_datasource.dart';
import 'package:kym/app/sync/sync_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) respond;
  late SupabaseClient client;
  late SupabaseRemoteSyncDataSource dataSource;

  setUp(() {
    requests = [];
    respond = (_) async => http.Response('', 201);
    client = SupabaseClient(
      'http://localhost:54321',
      'chave-publica',
      httpClient: MockClient((request) async {
        requests.add(request);
        final response = await respond(request);
        // O postgrest lê `response.request`, que a resposta montada à mão
        // não traz.
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    dataSource = SupabaseRemoteSyncDataSource(
      client,
      timeout: const Duration(milliseconds: 200),
    );
  });

  tearDown(() => client.dispose());

  http.Response jsonResponse(Object body, int status) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  const insert = RemoteOperation(
    kind: RemoteOperationKind.insert,
    table: 'maintenance_orders',
    id: 'o1',
    data: {'id': 'o1', 'status': 'aberta'},
  );

  group('push', () {
    test('inserção vira upsert que ignora duplicados', () async {
      await dataSource.push(insert);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/maintenance_orders');
      expect(request.url.queryParameters['on_conflict'], 'id');
      expect(request.headers['Prefer'], contains('ignore-duplicates'));
      expect(jsonDecode(request.body), {'id': 'o1', 'status': 'aberta'});
    });

    test('atualização envia só as colunas alteradas e filtra pelo id',
        () async {
      respond = (_) async => jsonResponse([
            {'id': 'o1'},
          ], 200);

      await dataSource.push(
        const RemoteOperation(
          kind: RemoteOperationKind.update,
          table: 'maintenance_orders',
          id: 'o1',
          data: {'id': 'o1', 'status': 'concluida'},
        ),
      );

      final request = requests.single;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.o1');
      expect(jsonDecode(request.body), {'status': 'concluida'});
    });

    test('atualização que não altera nenhuma linha é erro do servidor',
        () async {
      respond = (_) async => jsonResponse([], 200);

      await expectLater(
        dataSource.push(
          const RemoteOperation(
            kind: RemoteOperationKind.update,
            table: 'stores',
            id: 's1',
            data: {'name': 'Nova'},
          ),
        ),
        throwsA(
          isA<SyncServerException>().having((e) => e.code, 'code', 'no_rows'),
        ),
      );
    });

    test('atualização sem colunas não chama o servidor', () async {
      await dataSource.push(
        const RemoteOperation(
          kind: RemoteOperationKind.update,
          table: 'stores',
          id: 's1',
          data: {'id': 's1'},
        ),
      );

      expect(requests, isEmpty);
    });

    test('exclusão filtra pelo id', () async {
      respond = (_) async => http.Response('', 204);

      await dataSource.push(
        const RemoteOperation(
          kind: RemoteOperationKind.delete,
          table: 'photos',
          id: 'p1',
          data: {'id': 'p1'},
        ),
      );

      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.queryParameters['id'], 'eq.p1');
    });

    test('recusa do RLS é erro do servidor com o código', () async {
      respond = (_) async => jsonResponse({
            'code': '42501',
            'message': 'new row violates row-level security policy',
          }, 403);

      await expectLater(
        dataSource.push(insert),
        throwsA(
          isA<SyncServerException>().having((e) => e.code, 'code', '42501'),
        ),
      );
    });

    test('servidor fora do ar é falha de rede', () async {
      respond = (_) async => http.Response('Service Unavailable', 503);

      await expectLater(
        dataSource.push(insert),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('sem internet é falha de rede', () async {
      respond = (_) async => throw const SocketException('sem rota');

      await expectLater(
        dataSource.push(insert),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('sem resposta no prazo é falha de rede', () async {
      respond = (_) => Completer<http.Response>().future;

      await expectLater(
        dataSource.push(insert),
        throwsA(isA<SyncNetworkException>()),
      );
    });
  });

  group('sessão', () {
    test('sem usuário logado não há sessão', () async {
      expect(await dataSource.hasSession(), isFalse);
    });

    test('sessionReady ignora eventos sem sessão', () async {
      final events = <void>[];
      final sub = dataSource.sessionReady.listen(events.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      expect(events, isEmpty);
    });
  });

  group('classifySyncError', () {
    PostgrestException pg(String? code) =>
        PostgrestException(message: 'erro', code: code);

    test('passageiros viram falha de rede', () {
      for (final error in <Object>[
        const SocketException('x'),
        TimeoutException('x'),
        const HttpException('x'),
        http.ClientException('x'),
        const AuthException('jwt expired'),
        pg('PGRST301'),
        pg('401'),
        pg('429'),
        pg('502'),
        pg('08006'),
        pg('53300'),
        pg('57014'),
        pg('40001'),
      ]) {
        expect(classifySyncError(error), isA<SyncNetworkException>(),
            reason: '$error');
      }
    });

    test('recusas viram erro do servidor', () {
      for (final error in <Object>[
        pg('42501'),
        pg('23505'),
        pg('23503'),
        pg(null),
        pg('400'),
        StateError('bug'),
      ]) {
        expect(classifySyncError(error), isA<SyncServerException>(),
            reason: '$error');
      }
    });

    test('mantém o que já é SyncException', () {
      const error = SyncNetworkException('x');
      expect(classifySyncError(error), same(error));
      expect(error.toString(), 'Falha de rede: x');
      expect(const SyncServerException('y').toString(), 'Erro do servidor: y');
    });
  });
}
