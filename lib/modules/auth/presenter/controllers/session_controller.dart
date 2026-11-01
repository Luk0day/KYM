import 'package:flutter/foundation.dart';

import '../../domain/entities/authenticated_user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_out.dart';

/// Guarda o usuário autenticado enquanto o app está aberto.
///
/// É um singleton (vive o app todo): a splash restaura a sessão, o login a
/// inicia e a área logada a encerra.
class SessionController extends ChangeNotifier {
  SessionController(this._getCurrentUser, this._signOut);

  final GetCurrentUser _getCurrentUser;
  final SignOut _signOut;

  AuthenticatedUser? _user;

  AuthenticatedUser? get user => _user;
  bool get isAuthenticated => _user != null;

  /// Tenta restaurar uma sessão existente. Qualquer falha vira "sem sessão".
  Future<void> restore() async {
    try {
      _user = await _getCurrentUser();
    } catch (_) {
      _user = null;
    }
    notifyListeners();
  }

  void start(AuthenticatedUser user) {
    _user = user;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _signOut();
    } catch (_) {
      // Mesmo que falhe no servidor, a sessão local é encerrada.
    }
    _user = null;
    notifyListeners();
  }
}
