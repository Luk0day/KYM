import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/errors/auth_failure.dart';
import '../../infra/datasources/auth_datasource.dart';
import '../../infra/models/auth_user_model.dart';

class SupabaseAuthDataSource implements AuthDataSource {
  SupabaseAuthDataSource(this._client);

  final SupabaseClient _client;

  static const String _profilesTable = 'profiles';

  @override
  Future<AuthUserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _execute(() async {
        final response = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );

        final user = response.user;

        if (user == null) {
          throw const AuthFailure(AuthFailureType.unexpected);
        }

        return _fetchUserProfile(
          userId: user.id,
          email: user.email ?? email.trim(),
        );
      });
    } on AuthFailure catch (failure) {
      await _clearSessionIfProfileIsInvalid(failure);
      rethrow;
    }
  }

  @override
  Future<AuthUserModel?> getCurrentUser() async {
    try {
      return await _execute(() async {
        // Recupera a sessão e permite a renovação do token expirado.
        final session = await _client.auth.getSession();
        final user = session?.user;

        if (user == null) {
          return null;
        }

        return _fetchUserProfile(
          userId: user.id,
          email: user.email ?? '',
        );
      });
    } on AuthFailure catch (failure) {
      await _clearSessionIfProfileIsInvalid(failure);
      rethrow;
    }
  }

  @override
  Future<void> signOut() {
    return _execute(() async {
      await _client.auth.signOut();
    });
  }

  Future<AuthUserModel> _fetchUserProfile({
    required String userId,
    required String email,
  }) async {
    if (userId.trim().isEmpty || email.trim().isEmpty) {
      throw const AuthFailure(AuthFailureType.invalidProfile);
    }

    final profile = await _client
        .from(_profilesTable)
        .select('full_name, role')
        .eq('id', userId)
        .maybeSingle();

    if (profile == null) {
      throw const AuthFailure(AuthFailureType.profileNotFound);
    }

    final rawRole = profile['role'];
    final rawDisplayName = profile['full_name'];

    if (rawRole is! String || rawRole.trim().isEmpty) {
      throw const AuthFailure(AuthFailureType.invalidProfile);
    }

    if (rawDisplayName != null && rawDisplayName is! String) {
      throw const AuthFailure(AuthFailureType.invalidProfile);
    }

    // full_name tem default '' na migration: nome vazio equivale a sem nome.
    final displayName = (rawDisplayName as String?)?.trim();

    return AuthUserModel(
      id: userId,
      email: email.trim(),
      displayName: (displayName == null || displayName.isEmpty)
          ? null
          : displayName,
      role: rawRole.trim(),
    );
  }

  Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw const AuthFailure(AuthFailureType.network);
    } on SocketException {
      throw const AuthFailure(AuthFailureType.network);
    } on TimeoutException {
      throw const AuthFailure(AuthFailureType.network);
    } on AuthException catch (error) {
      throw _mapAuthException(error);
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (_) {
      throw const AuthFailure(AuthFailureType.unexpected);
    }
  }

  AuthFailure _mapAuthException(AuthException error) {
    final code = error.code?.toLowerCase();
    final message = error.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return const AuthFailure(AuthFailureType.invalidCredentials);
    }

    return const AuthFailure(AuthFailureType.unexpected);
  }

  AuthFailure _mapPostgrestException(PostgrestException error) {
    // 42501: falta de privilégio no PostgreSQL.
    if (error.code == '42501') {
      return const AuthFailure(AuthFailureType.accessDenied);
    }

    return const AuthFailure(AuthFailureType.unexpected);
  }

  Future<void> _clearSessionIfProfileIsInvalid(
      AuthFailure failure,
      ) async {
    final shouldClearSession =
        failure.type == AuthFailureType.profileNotFound ||
            failure.type == AuthFailureType.invalidProfile ||
            failure.type == AuthFailureType.accessDenied;

    if (!shouldClearSession) {
      return;
    }

    // Não mantém uma sessão autenticada sem perfil válido no KYM.
    // A falha original deve ser preservada caso o logout também falhe.
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Preserva a falha original para a camada que chamou o datasource.
    }
  }
}
