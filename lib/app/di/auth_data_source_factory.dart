import 'package:supabase_flutter/supabase_flutter.dart';

import '../../modules/auth/external/datasources/supabase_auth_datasource.dart';
import '../../modules/auth/infra/datasources/auth_datasource.dart';
import '../../modules/auth/infra/datasources/fake_auth_datasource.dart';
import '../config/env.dart';

/// Único ponto que decide qual [AuthDataSource] o app usa.
///
/// Com `USE_FAKE_AUTH=true` no `.env` usa o fake; caso contrário, o Supabase
/// (que precisa ter sido inicializado antes).
AuthDataSource createAuthDataSource() {
  if (Env.useFakeAuth) {
    return FakeAuthDataSource();
  }
  return SupabaseAuthDataSource(Supabase.instance.client);
}
