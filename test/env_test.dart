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
}
