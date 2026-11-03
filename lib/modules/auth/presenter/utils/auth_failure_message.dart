import '../../domain/errors/auth_failure.dart';

extension AuthFailureMessage on AuthFailureType {
  String get userMessage {
    switch (this) {
      case AuthFailureType.invalidCredentials:
        return 'E-mail ou senha incorretos. Confira os dados e tente novamente.';
      case AuthFailureType.profileNotFound:
        return 'Seu acesso ainda não foi configurado no KYM. '
            'Procure o administrador da sua loja.';
      case AuthFailureType.invalidProfile:
        return 'Não foi possível validar o seu perfil. '
            'Procure o administrador da sua loja.';
      case AuthFailureType.accessDenied:
        return 'Você não tem permissão para acessar o KYM.';
      case AuthFailureType.network:
        return 'Sem conexão com o servidor. '
            'Verifique sua internet e tente novamente.';
      case AuthFailureType.rateLimited:
        return 'Muitas tentativas em pouco tempo. '
            'Aguarde alguns minutos e tente novamente.';
      case AuthFailureType.cancelled:
        return 'Login cancelado.';
      case AuthFailureType.unexpected:
        return 'Algo deu errado ao entrar. Tente novamente em instantes.';
    }
  }
}
