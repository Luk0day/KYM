abstract final class LoginValidators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Informe seu e-mail.';
    }
    if (!_emailPattern.hasMatch(text)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe sua senha.';
    }
    return null;
  }

  static const int minNewPasswordLength = 6;

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe a nova senha.';
    }
    if (value.length < minNewPasswordLength) {
      return 'Use pelo menos $minNewPasswordLength caracteres.';
    }
    return null;
  }

  static String? passwordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirme a nova senha.';
    }
    if (value != password) {
      return 'As senhas não conferem.';
    }
    return null;
  }
}
