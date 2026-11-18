import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/errors/auth_failure.dart';
import 'package:kym/modules/auth/presenter/utils/auth_failure_message.dart';
import 'package:kym/modules/auth/presenter/utils/login_validators.dart';
import 'package:kym/modules/auth/presenter/utils/password_reset_failure_message.dart';
import 'package:kym/modules/auth/presenter/utils/password_update_failure_message.dart';

void main() {
  group('nova senha', () {
    test('vazia pede a nova senha', () {
      expect(LoginValidators.newPassword(null), 'Informe a nova senha.');
      expect(LoginValidators.newPassword(''), 'Informe a nova senha.');
    });

    test('curta pede o mínimo de caracteres', () {
      expect(
        LoginValidators.newPassword('12345'),
        'Use pelo menos ${LoginValidators.minNewPasswordLength} caracteres.',
      );
    });

    test('com o mínimo é válida', () {
      expect(LoginValidators.newPassword('123456'), isNull);
    });
  });

  group('confirmação', () {
    test('vazia pede a confirmação', () {
      expect(
        LoginValidators.passwordConfirmation('', 'novaSenha1'),
        'Confirme a nova senha.',
      );
    });

    test('diferente avisa que não confere', () {
      expect(
        LoginValidators.passwordConfirmation('outra', 'novaSenha1'),
        'As senhas não conferem.',
      );
    });

    test('igual é válida', () {
      expect(
        LoginValidators.passwordConfirmation('novaSenha1', 'novaSenha1'),
        isNull,
      );
    });
  });

  group('mensagens', () {
    for (final type in AuthFailureType.values) {
      test('${type.name} tem mensagem em todas as telas', () {
        expect(type.userMessage.trim(), isNotEmpty);
        expect(type.passwordResetMessage.trim(), isNotEmpty);
        expect(type.passwordUpdateMessage.trim(), isNotEmpty);
      });
    }

    test('link inválido orienta a pedir um novo link', () {
      expect(
        AuthFailureType.recoveryLinkInvalid.passwordUpdateMessage,
        contains('novo link'),
      );
    });

    test('senha fraca cita o mínimo de caracteres', () {
      expect(
        AuthFailureType.weakPassword.passwordUpdateMessage,
        contains('${LoginValidators.minNewPasswordLength}'),
      );
    });
  });
}
