import '../../domain/errors/auth_failure.dart';

extension PasswordUpdateFailureMessage on AuthFailureType {
  String get passwordUpdateMessage {
    switch (this) {
      case AuthFailureType.weakPassword:
        return 'Essa senha é fraca. Use pelo menos 6 caracteres, '
            'misturando letras e números.';
      case AuthFailureType.samePassword:
        return 'A nova senha precisa ser diferente da atual.';
      case AuthFailureType.recoveryLinkInvalid:
        return 'Este link expirou ou já foi usado. '
            'Peça um novo link de redefinição.';
      case AuthFailureType.network:
        return 'Sem conexão com o servidor. '
            'Verifique sua internet e tente novamente.';
      case AuthFailureType.rateLimited:
        return 'Muitas tentativas em pouco tempo. '
            'Aguarde alguns minutos e tente novamente.';
      case AuthFailureType.invalidCredentials:
      case AuthFailureType.profileNotFound:
      case AuthFailureType.invalidProfile:
      case AuthFailureType.accessDenied:
      case AuthFailureType.cancelled:
      case AuthFailureType.unexpected:
        return 'Não foi possível salvar a nova senha. '
            'Tente novamente em instantes.';
    }
  }
}
