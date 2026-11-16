import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/auth_routes.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/auth/domain/entities/user_role_permissions.dart';
import 'package:kym/modules/auth/presenter/guards/role_guard.dart';
import 'package:kym/modules/home/home_routes.dart';

void main() {
  final state = RouteState(uri: Uri.parse(HomeRoutes.qrCodes));

  String fallback(UserRole role) => HomeRoutes.of(role.initialDestination);

  RoleGuard guardFor(UserRole? role, {Set<UserRole>? allowed}) => RoleGuard(
    allowed: allowed ?? {UserRole.gestor},
    currentRole: () => role,
    fallbackRoute: fallback,
  );

  test('sem sessão redireciona para o login', () {
    expect(guardFor(null)(state), AuthRoutes.login);
  });

  test('perfil permitido passa', () {
    expect(guardFor(UserRole.gestor)(state), isNull);
  });

  test('técnico na rota de QR Codes volta para o Painel', () {
    expect(guardFor(UserRole.tecnico)(state), HomeRoutes.painel);
  });

  test('lojista em rota proibida volta para Lojas', () {
    expect(guardFor(UserRole.lojista)(state), HomeRoutes.lojas);
  });

  group('forDestination', () {
    RoleGuard destinationGuard(AppDestination destination, UserRole role) =>
        RoleGuard.forDestination(
          destination,
          currentRole: () => role,
          fallbackRoute: fallback,
        );

    test('libera exatamente os perfis que têm o destino na barra', () {
      for (final destination in AppDestination.values) {
        for (final role in UserRole.values) {
          final result = destinationGuard(destination, role)(state);
          if (role.canAccess(destination)) {
            expect(result, isNull, reason: '$role em $destination');
          } else {
            expect(
              result,
              HomeRoutes.of(role.initialDestination),
              reason: '$role em $destination',
            );
          }
        }
      }
    });

    test('gestor não abre o leitor de QR', () {
      expect(
        destinationGuard(AppDestination.qr, UserRole.gestor)(state),
        HomeRoutes.painel,
      );
    });

    test('lojista não abre a Agenda', () {
      expect(
        destinationGuard(AppDestination.agenda, UserRole.lojista)(state),
        HomeRoutes.lojas,
      );
    });
  });
}
