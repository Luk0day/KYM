import 'package:flutter/foundation.dart';

import '../../domain/errors/auth_failure.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../utils/password_reset_failure_message.dart';

enum ForgotPasswordStatus { idle, loading, success, failure }

class ForgotPasswordController extends ChangeNotifier {
  ForgotPasswordController(this._sendPasswordResetEmail);

  final SendPasswordResetEmail _sendPasswordResetEmail;

  ForgotPasswordStatus _status = ForgotPasswordStatus.idle;
  String? _errorMessage;
  String? _requestedEmail;
  bool _disposed = false;

  ForgotPasswordStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get requestedEmail => _requestedEmail;
  bool get isLoading => _status == ForgotPasswordStatus.loading;

  Future<void> submit({required String email}) async {
    if (isLoading) {
      return;
    }

    _status = ForgotPasswordStatus.loading;
    _errorMessage = null;
    _requestedEmail = null;
    notifyListeners();

    try {
      await _sendPasswordResetEmail(email: email);
      _requestedEmail = email.trim();
      _status = ForgotPasswordStatus.success;
    } on AuthFailure catch (failure) {
      _fail(failure.type);
    } catch (_) {
      _fail(AuthFailureType.unexpected);
    }

    notifyListeners();
  }

  void clearFeedback() {
    final hasFeedback =
        _status == ForgotPasswordStatus.failure ||
        _status == ForgotPasswordStatus.success;
    if (!hasFeedback) {
      return;
    }
    _status = ForgotPasswordStatus.idle;
    _errorMessage = null;
    _requestedEmail = null;
    notifyListeners();
  }

  void _fail(AuthFailureType type) {
    _status = ForgotPasswordStatus.failure;
    _errorMessage = type.passwordResetMessage;
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
