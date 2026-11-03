import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/errors/auth_failure.dart';
import '../../infra/datasources/google_id_token_provider.dart';

class GoogleSignInIdTokenProvider implements GoogleIdTokenProvider {
  GoogleSignInIdTokenProvider({
    required this.serverClientId,
    GoogleSignIn? googleSignIn,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Client ID do cliente OAuth do tipo **Web** (o mesmo cadastrado no Supabase).
  final String serverClientId;
  final GoogleSignIn _googleSignIn;

  Future<void>? _initialization;

  Future<void> _ensureInitialized() {
    // initialize só pode rodar uma vez por processo.
    return _initialization ??= _googleSignIn
        .initialize(serverClientId: serverClientId)
        .catchError((Object error) {
      _initialization = null;
      throw error;
    });
  }

  @override
  Future<String> fetchIdToken() async {
    try {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure(AuthFailureType.unexpected);
      }
      return idToken;
    } on AuthFailure {
      rethrow;
    } on GoogleSignInException catch (error) {
      debugPrint('GoogleSignInException: ${error.code} ${error.description}');
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure(AuthFailureType.cancelled);
      }
      if (error.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthFailure(AuthFailureType.network);
      }
      throw const AuthFailure(AuthFailureType.unexpected);
    } catch (_) {
      throw const AuthFailure(AuthFailureType.unexpected);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
    } catch (_) {
      // Sair do KYM não deve falhar por causa da conta Google.
    }
  }
}
