import '../../domain/errors/auth_failure.dart';

extension PasswordResetFailureMessage on AuthFailureType {
  String get passwordResetMessage {
    switch (this) {
      case AuthFailureType.network:
        return 'Sem conexão com o servidor. '
            'Verifique sua internet e tente novamente.';
      case AuthFailureType.rateLimited:
        return 'Muitos pedidos de recuperação em pouco tempo. '
            'Aguarde alguns minutos e tente novamente.';
      case AuthFailureType.invalidCredentials:
      case AuthFailureType.profileNotFound:
      case AuthFailureType.invalidProfile:
      case AuthFailureType.cancelled:
      case AuthFailureType.accessDenied:
      case AuthFailureType.unexpected:
        return 'Não foi possível enviar o e-mail de recuperação. '
            'Tente novamente em instantes.';
    }
  }
}
