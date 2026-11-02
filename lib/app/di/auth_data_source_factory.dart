import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modules/auth/external/datasources/supabase_auth_datasource.dart';
import '../../modules/auth/infra/datasources/auth_datasource.dart';
import '../../modules/auth/infra/datasources/fake_auth_datasource.dart';
import '../config/env.dart';
import '../storage/secure_key_value_store.dart';

/// O Supabase precisa ter sido inicializado antes (feito no `main`).
AuthDataSource createAuthDataSource() {
  if (Env.useFakeAuth) {
    // Persiste só o id da conta fake, para simular "restaurar sessão".
    return FakeAuthDataSource(sessionStore: SecureKeyValueStore());
  }
  return SupabaseAuthDataSource(Supabase.instance.client);
}
