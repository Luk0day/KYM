import 'package:flutter/widgets.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../auth_routes.dart';
import '../../domain/entities/password_recovery_event.dart';
import '../controllers/password_recovery_controller.dart';

class PasswordRecoveryListener extends StatefulWidget {
  const PasswordRecoveryListener({
    super.key,
    required this.controller,
    required this.child,
  });

  final PasswordRecoveryController controller;
  final Widget child;

  @override
  State<PasswordRecoveryListener> createState() =>
      _PasswordRecoveryListenerState();
}

class _PasswordRecoveryListenerState extends State<PasswordRecoveryListener> {
  @override
  void initState() {
    super.initState();
    widget.controller
      ..addListener(_handle)
      ..start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handle);
    super.dispose();
  }

  /// Leva para a tela certa assim que o link chega, esteja o app em qualquer
  /// tela. Usa o setNewRoutePath do router porque este widget fica acima do
  /// Navigator, onde context.navigate não alcança.
  void _handle() {
    if (!mounted || widget.controller.pending == null) {
      return;
    }
    final route = switch (widget.controller.consume()!) {
      PasswordRecoveryEvent.started => AuthRoutes.resetPassword,
      PasswordRecoveryEvent.linkInvalid => AuthRoutes.forgotPasswordLinkInvalid,
    };
    ModularApp.routerConfigOf(context).routerDelegate
        .setNewRoutePath(RouteState(uri: Uri.parse(route)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
