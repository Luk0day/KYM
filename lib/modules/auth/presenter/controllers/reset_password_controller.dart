import 'package:flutter/foundation.dart';

import '../../domain/errors/auth_failure.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/update_password.dart';
import '../utils/password_update_failure_message.dart';

enum ResetPasswordStatus { idle, loading, success, failure }

class ResetPasswordController extends ChangeNotifier {
  ResetPasswordController(this._updatePassword, this._signOut);

  final UpdatePassword _updatePassword;
  final SignOut _signOut;

  ResetPasswordStatus _status = ResetPasswordStatus.idle;
  AuthFailureType? _failure;
  bool _disposed = false;

  ResetPasswordStatus get status => _status;
  bool get isLoading => _status == ResetPasswordStatus.loading;
  String? get errorMessage => _failure?.passwordUpdateMessage;
  bool get isLinkInvalid => _failure == AuthFailureType.recoveryLinkInvalid;

  Future<void> submit({required String password}) async {
    if (isLoading) {
      return;
    }

    _status = ResetPasswordStatus.loading;
    _failure = null;
    notifyListeners();

    try {
      await _updatePassword(password: password);
      _status = ResetPasswordStatus.success;
    } on AuthFailure catch (failure) {
      _fail(failure.type);
    } catch (_) {
      _fail(AuthFailureType.unexpected);
    }

    notifyListeners();
  }

  /// Sai sem trocar a senha: encerra a sessão de recuperação para ela não
  /// dar acesso ao app.
  Future<void> cancel() async {
    try {
      await _signOut();
    } on Object {
      return;
    }
  }

  void clearFeedback() {
    if (_status != ResetPasswordStatus.failure) {
      return;
    }
    _status = ResetPasswordStatus.idle;
    _failure = null;
    notifyListeners();
  }

  void _fail(AuthFailureType type) {
    _status = ResetPasswordStatus.failure;
    _failure = type;
  }

  @override
  void notifyListeners() {
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
