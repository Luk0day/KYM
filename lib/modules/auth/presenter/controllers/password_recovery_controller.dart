import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/password_recovery_event.dart';
import '../../domain/usecases/watch_password_recovery.dart';

/// Vive o app todo e guarda o último evento do link de redefinição até a
/// interface consumir. Assim, na abertura a frio pelo link, o evento que chega
/// antes de a primeira tela existir não se perde.
class PasswordRecoveryController extends ChangeNotifier {
  PasswordRecoveryController(this._watchPasswordRecovery);

  final WatchPasswordRecovery _watchPasswordRecovery;

  StreamSubscription<PasswordRecoveryEvent>? _subscription;
  PasswordRecoveryEvent? _pending;

  PasswordRecoveryEvent? get pending => _pending;
  bool get isRecovering => _pending == PasswordRecoveryEvent.started;

  void start() {
    _subscription ??= _watchPasswordRecovery().listen((event) {
      _pending = event;
      notifyListeners();
    });
  }

  PasswordRecoveryEvent? consume() {
    final event = _pending;
    _pending = null;
    return event;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
