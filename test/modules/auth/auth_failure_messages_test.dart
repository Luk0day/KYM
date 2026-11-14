import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/presenter/utils/auth_failure_message.dart';
import 'package:kym/modules/auth/presenter/utils/password_reset_failure_message.dart';

void main() {
  group('mensagem de recuperação de senha', () {
    for (final type in AuthFailureType.values) {
      test('${type.name} tem mensagem preenchida', () {
        expect(type.passwordResetMessage.trim(), isNotEmpty);
      });
    }

    test('limite de envios orienta a aguardar', () {
      expect(
        AuthFailureType.rateLimited.passwordResetMessage,
        contains('Aguarde'),
      );
    });

    test('falha de rede orienta a verificar a internet', () {
      expect(
        AuthFailureType.network.passwordResetMessage,
        contains('internet'),
      );
    });
  });

  test('o login também orienta a aguardar quando o limite é atingido', () {
    expect(AuthFailureType.rateLimited.userMessage, contains('Aguarde'));
  });
}
