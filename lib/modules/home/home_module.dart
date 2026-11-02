import 'package:flutter_modular/flutter_modular.dart';

import '../auth/auth_routes.dart';
import '../auth/presenter/controllers/session_controller.dart';
import 'home_routes.dart';
import 'presenter/pages/home_page.dart';

class HomeModule extends Module {
  @override
  String? get path => HomeRoutes.root;

  @override
  void register(ModularContext c) {
    c.route(
      '/',
      guards: [
        (_) => inject<SessionController>().isAuthenticated
            ? null
            : AuthRoutes.login,
      ],
      child: (context, _) => HomePage(
        session: inject<SessionController>(),
        onSignedOut: () => context.navigate(AuthRoutes.login),
      ),
    );
  }
}
