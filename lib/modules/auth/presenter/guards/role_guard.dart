import 'package:flutter_modular/flutter_modular.dart';

import '../../auth_routes.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/entities/user_role_permissions.dart';

class RoleGuard {
  const RoleGuard({
    required this.allowed,
    required this.currentRole,
    required this.fallbackRoute,
  });

  factory RoleGuard.forDestination(
    AppDestination destination, {
    required UserRole? Function() currentRole,
    required String Function(UserRole role) fallbackRoute,
  }) => RoleGuard(
    allowed: {
      for (final role in UserRole.values)
        if (role.canAccess(destination)) role,
    },
    currentRole: currentRole,
    fallbackRoute: fallbackRoute,
  );

  final Set<UserRole> allowed;
  final UserRole? Function() currentRole;
  final String Function(UserRole role) fallbackRoute;

  /// Devolve null para liberar a rota, o login quando não há sessão ou
  /// [fallbackRoute] quando o perfil não está em [allowed].
  String? call(RouteState state) {
    final role = currentRole();
    if (role == null) return AuthRoutes.login;
    if (allowed.contains(role)) return null;
    return fallbackRoute(role);
  }
}
