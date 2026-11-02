import 'package:flutter/foundation.dart';

import '../../domain/entities/authenticated_user.dart';
import '../../domain/errors/auth_failure.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../utils/auth_failure_message.dart';

enum LoginStatus { idle, loading, success, failure }

class LoginController extends ChangeNotifier {
  LoginController(this._signInWithEmail);

  final SignInWithEmail _signInWithEmail;

  LoginStatus _status = LoginStatus.idle;
  String? _errorMessage;
  AuthenticatedUser? _user;
  bool _disposed = false;

  LoginStatus get status => _status;
  String? get errorMessage => _errorMessage;
  AuthenticatedUser? get user => _user;
  bool get isLoading => _status == LoginStatus.loading;

  Future<void> submit({
    required String email,
    required String password,
  }) async {
    if (isLoading) {
      return;
    }

    _status = LoginStatus.loading;
    _errorMessage = null;
    _user = null;
    notifyListeners();

    try {
      _user = await _signInWithEmail(email: email, password: password);
      _status = LoginStatus.success;
    } on AuthFailure catch (failure) {
      _fail(failure.type);
    } catch (_) {
      _fail(AuthFailureType.unexpected);
    }

    notifyListeners();
  }

  void clearError() {
    if (_status != LoginStatus.failure) {
      return;
    }
    _status = LoginStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void _fail(AuthFailureType type) {
    _status = LoginStatus.failure;
    _errorMessage = type.userMessage;
  }

  @override
  void notifyListeners() {
    // Evita erro se a tela for fechada enquanto o login ainda está em curso.
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
