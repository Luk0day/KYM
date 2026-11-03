import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']!;

  static String? get passwordResetRedirectUrl {
    final value = dotenv.env['PASSWORD_RESET_REDIRECT_URL']?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
  /// Client ID do cliente OAuth **Web** do Google Cloud (o mesmo usado no
  /// provedor Google do Supabase). Vazio desativa o login com Google.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';

  /// Permite rodar o app antes de o Supabase estar configurado na nuvem.
  static bool get useFakeAuth =>
      dotenv.env['USE_FAKE_AUTH']?.trim().toLowerCase() == 'true';
}
