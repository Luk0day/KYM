import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY']!;

  /// Quando `true`, o app usa um datasource de autenticação em memória
  /// no lugar do Supabase. Útil enquanto o backend não está configurado.
  static bool get useFakeAuth =>
      dotenv.env['USE_FAKE_AUTH']?.trim().toLowerCase() == 'true';
}
