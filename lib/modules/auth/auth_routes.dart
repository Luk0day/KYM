abstract final class AuthRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  static const String noticeParam = 'aviso';
  static const String linkInvalidNotice = 'link-invalido';
  static const String forgotPasswordLinkInvalid =
      '$forgotPassword?$noticeParam=$linkInvalidNotice';
}
