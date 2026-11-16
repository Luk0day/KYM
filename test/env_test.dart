import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/config/env.dart';

void main() {
  test('Env lê as variáveis do Supabase', () {
    dotenv.loadFromString(envString: '''
SUPABASE_URL=https://exemplo.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_teste
''');

    expect(Env.supabaseUrl, 'https://exemplo.supabase.co');
    expect(Env.supabasePublishableKey, 'sb_publishable_teste');
  });

  group('PASSWORD_RESET_REDIRECT_URL', () {
    test('lê o deep link da nova senha', () {
      dotenv.loadFromString(
        envString:
            'PASSWORD_RESET_REDIRECT_URL=br.edu.ifpe.mobile.kym://reset-password',
      );

      expect(
        Env.passwordResetRedirectUrl,
        'br.edu.ifpe.mobile.kym://reset-password',
      );
    });

    test('valor vazio vira null para não enviar redirectTo vazio', () {
      dotenv.loadFromString(envString: 'PASSWORD_RESET_REDIRECT_URL=   ');

      expect(Env.passwordResetRedirectUrl, isNull);
    });

    test('variável ausente vira null', () {
      dotenv.loadFromString(envString: 'SUPABASE_URL=https://x.supabase.co');

      expect(Env.passwordResetRedirectUrl, isNull);
    });
  });
}
