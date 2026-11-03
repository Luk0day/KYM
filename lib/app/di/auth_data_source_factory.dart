import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modules/auth/external/datasources/google_sign_in_id_token_provider.dart';
import '../../modules/auth/external/datasources/supabase_auth_datasource.dart';
import '../../modules/auth/infra/datasources/auth_datasource.dart';
import '../../modules/auth/infra/datasources/fake_auth_datasource.dart';
import '../config/env.dart';
import '../storage/secure_key_value_store.dart';

AuthDataSource createAuthDataSource() {
  if (Env.useFakeAuth) {
    return FakeAuthDataSource(sessionStore: SecureKeyValueStore());
  }

  final webClientId = Env.googleWebClientId;

  return SupabaseAuthDataSource(
    Supabase.instance.client,
    googleProvider: webClientId.isEmpty
        ? null
        : GoogleSignInIdTokenProvider(serverClientId: webClientId),
  );
}
