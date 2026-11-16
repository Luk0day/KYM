import 'package:flutter_test/flutter_test.dart';
import 'package:kym/shared/domain/qr_payload.dart';
import 'package:uuid/uuid.dart';

const _token = '3f2b8c1e-9a4d-4e6f-8b7a-1c2d3e4f5a6b';
const _tokenUpper = '3F2B8C1E-9A4D-4E6F-8B7A-1C2D3E4F5A6B';

QrPayload _validPayload(String raw) {
  final result = QrPayload.parse(raw);
  expect(result, isA<QrValid>(), reason: 'esperava QR válido para "$raw"');
  return (result as QrValid).payload;
}

void main() {
  group('QR válido', () {
    test('loja', () {
      final payload = _validPayload('kym:1:S:$_token');

      expect(payload.type, QrTargetType.store);
      expect(payload.token, _token);
    });

    test('equipamento', () {
      final payload = _validPayload('kym:1:E:$_token');

      expect(payload.type, QrTargetType.equipment);
      expect(payload.token, _token);
    });

    test('loja e equipamento com o mesmo token são payloads diferentes', () {
      expect(
        _validPayload('kym:1:S:$_token'),
        isNot(_validPayload('kym:1:E:$_token')),
      );
    });
  });

  group('tolerância no texto lido', () {
    test('maiúsculas em tudo: o token sai em minúsculas', () {
      final payload = _validPayload('KYM:1:S:$_tokenUpper');

      expect(payload.type, QrTargetType.store);
      expect(payload.token, _token);
    });

    test('tipo em minúscula', () {
      expect(_validPayload('kym:1:e:$_token').type, QrTargetType.equipment);
    });

    test('espaços e quebra de linha nas pontas', () {
      expect(_validPayload('  kym:1:S:$_token \r\n').token, _token);
    });

    test('espaços em volta dos separadores', () {
      final payload = _validPayload(' kym : 1 : E : $_token ');

      expect(payload.type, QrTargetType.equipment);
      expect(payload.token, _token);
    });
  });

  group('QR de outro sistema', () {
    final cases = <String, String>{
      'URL': 'https://example.com/loja/$_token',
      'URL com porta': 'http://localhost:8080/kym:1:S:$_token',
      'texto qualquer': 'olá, mundo',
      'só o uuid': _token,
      'texto vazio': '',
      'só espaços': '   \n ',
      'esquema parecido': 'kymx:1:S:$_token',
      'prefixo no meio': 'x:kym:1:S:$_token',
      'outro formato com dois pontos': 'WIFI:S:rede;T:WPA;P:senha;;',
      'vCard': 'BEGIN:VCARD\nVERSION:3.0\nEND:VCARD',
    };

    cases.forEach((name, raw) {
      test(name, () {
        expect(QrPayload.parse(raw), isA<QrForeign>());
      });
    });
  });

  group('versão não suportada', () {
    test('versão 2', () {
      final result = QrPayload.parse('kym:2:S:$_token');

      expect(result, isA<QrUnsupportedVersion>());
      expect((result as QrUnsupportedVersion).version, '2');
    });

    test('versão 0', () {
      expect(
        QrPayload.parse('kym:0:S:$_token'),
        const QrUnsupportedVersion('0'),
      );
    });

    test('versão futura com outra forma de texto não vira malformado', () {
      expect(QrPayload.parse('kym:3:X'), const QrUnsupportedVersion('3'));
      expect(
        QrPayload.parse('kym:2:S:$_token:extra'),
        const QrUnsupportedVersion('2'),
      );
    });

    test('versão numérica enorme não estoura: continua não suportada', () {
      expect(
        QrPayload.parse('kym:99999999999999999999999:S:$_token'),
        const QrUnsupportedVersion('99999999999999999999999'),
      );
    });

    test('maiúsculas e espaços não atrapalham', () {
      expect(
        QrPayload.parse(' KYM:2:s:$_tokenUpper '),
        const QrUnsupportedVersion('2'),
      );
    });
  });

  group('QR do KYM malformado', () {
    final cases = <String, String>{
      'uuid inválido': 'kym:1:S:nao-e-um-uuid',
      'uuid sem hífens': 'kym:1:S:${_token.replaceAll('-', '')}',
      'uuid com um caractere a menos': 'kym:1:S:${_token.substring(1)}',
      'uuid com caractere fora de hexadecimal':
          'kym:1:S:${_token.replaceFirst('3', 'g')}',
      'uuid entre chaves': 'kym:1:S:{$_token}',
      'token vazio': 'kym:1:S:',
      'token faltando': 'kym:1:S',
      'tipo e token faltando': 'kym:1',
      'só o prefixo': 'kym',
      'prefixo com dois pontos': 'kym:',
      'tipo desconhecido': 'kym:1:X:$_token',
      'tipo vazio': 'kym:1::$_token',
      'tipo com mais de uma letra': 'kym:1:SE:$_token',
      'versão não numérica': 'kym:a:S:$_token',
      'versão vazia': 'kym::S:$_token',
      'versão negativa': 'kym:-1:S:$_token',
      'versão com zero à esquerda': 'kym:01:S:$_token',
      'versão com vários zeros': 'kym:001:S:$_token',
      'versão com sinal': 'kym:+1:S:$_token',
      'versão decimal': 'kym:1.0:S:$_token',
      'parte sobrando na versão 1': 'kym:1:S:$_token:extra',
    };

    cases.forEach((name, raw) {
      test(name, () {
        expect(QrPayload.parse(raw), isA<QrMalformed>());
      });
    });
  });

  group('encode', () {
    test('loja', () {
      expect(
        QrPayload(type: QrTargetType.store, token: _token).encode(),
        'kym:1:S:$_token',
      );
    });

    test('equipamento', () {
      expect(
        QrPayload(type: QrTargetType.equipment, token: _token).encode(),
        'kym:1:E:$_token',
      );
    });

    test('grava o token em minúsculas mesmo se vier em maiúsculas', () {
      expect(
        QrPayload(type: QrTargetType.store, token: _tokenUpper).encode(),
        'kym:1:S:$_token',
      );
    });

    test('token que não é uuid é recusado na criação', () {
      expect(
        () => QrPayload(type: QrTargetType.store, token: 'abc'),
        throwsArgumentError,
      );
      expect(
        () => QrPayload(type: QrTargetType.store, token: ''),
        throwsArgumentError,
      );
    });
  });

  group('encode e parse são inversos', () {
    test('payload -> encode -> parse devolve o mesmo payload', () {
      const uuid = Uuid();
      for (final type in QrTargetType.values) {
        for (var i = 0; i < 100; i++) {
          final original = QrPayload(type: type, token: uuid.v4());

          expect(QrPayload.parse(original.encode()), QrValid(original));
        }
      }
    });

    test('texto canônico -> parse -> encode devolve o mesmo texto', () {
      for (final raw in ['kym:1:S:$_token', 'kym:1:E:$_token']) {
        expect(_validPayload(raw).encode(), raw);
      }
    });

    test('o texto lido com ruído volta ao formato canônico', () {
      expect(
        _validPayload(' KYM:1:e:$_tokenUpper\n').encode(),
        'kym:1:E:$_token',
      );
    });
  });

  group('igualdade e apresentação', () {
    test('payloads com os mesmos dados são iguais', () {
      final a = QrPayload(type: QrTargetType.store, token: _token);
      final b = QrPayload(type: QrTargetType.store, token: _tokenUpper);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('resultados com os mesmos dados são iguais', () {
      final payload = QrPayload(type: QrTargetType.store, token: _token);

      expect(QrValid(payload), QrValid(payload));
      expect(QrValid(payload).hashCode, QrValid(payload).hashCode);
      expect(
        const QrUnsupportedVersion('2').hashCode,
        const QrUnsupportedVersion('2').hashCode,
      );
      expect(
        const QrUnsupportedVersion('2'),
        isNot(const QrUnsupportedVersion('3')),
      );
    });

    test('toString mostra tipo e token', () {
      expect(
        QrPayload(type: QrTargetType.equipment, token: _token).toString(),
        'QrPayload(equipment, $_token)',
      );
    });

    test('fromCode conhece S e E e recusa o resto', () {
      expect(QrTargetType.fromCode('s'), QrTargetType.store);
      expect(QrTargetType.fromCode('E'), QrTargetType.equipment);
      expect(QrTargetType.fromCode('X'), isNull);
      expect(QrTargetType.fromCode(''), isNull);
    });
  });

  test('o resultado cobre todos os casos num switch exaustivo', () {
    String describe(QrParseResult result) => switch (result) {
      QrValid(:final payload) => 'válido:${payload.type.name}',
      QrForeign() => 'outro sistema',
      QrUnsupportedVersion(:final version) => 'versão:$version',
      QrMalformed() => 'malformado',
    };

    expect(describe(QrPayload.parse('kym:1:S:$_token')), 'válido:store');
    expect(describe(QrPayload.parse('https://x.com')), 'outro sistema');
    expect(describe(QrPayload.parse('kym:2:S:$_token')), 'versão:2');
    expect(describe(QrPayload.parse('kym:1:S:x')), 'malformado');
  });
}
