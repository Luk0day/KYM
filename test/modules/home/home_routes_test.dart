import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/user_role_permissions.dart';
import 'package:kym/modules/home/home_routes.dart';
import 'package:kym/modules/scanner/scanner_routes.dart';

void main() {
  test('cada destino tem uma rota própria dentro de /home', () {
    final routes = AppDestination.values.map(HomeRoutes.of).toList();

    expect(routes.toSet(), hasLength(AppDestination.values.length));
    for (final destination in AppDestination.values) {
      if (destination == AppDestination.qr) continue;
      expect(
        HomeRoutes.of(destination),
        startsWith('${HomeRoutes.root}/'),
        reason: '$destination',
      );
    }
  });

  test('o leitor abre em /scanner, fora do shell', () {
    expect(HomeRoutes.of(AppDestination.qr), ScannerRoutes.root);
  });

  test('rota de QR Codes é /home/qr-codes', () {
    expect(HomeRoutes.of(AppDestination.qrCodes), '/home/qr-codes');
  });

  group('destinationOf', () {
    test('reconhece a rota da aba', () {
      for (final destination in AppDestination.values) {
        expect(
          HomeRoutes.destinationOf(HomeRoutes.of(destination)),
          destination,
        );
      }
    });

    test('reconhece rotas dentro da aba', () {
      expect(
        HomeRoutes.destinationOf('${HomeRoutes.lojas}/123'),
        AppDestination.lojas,
      );
    });

    test('não confunde /qr com /qr-codes', () {
      expect(
        HomeRoutes.destinationOf(HomeRoutes.qrCodes),
        AppDestination.qrCodes,
      );
      expect(
        HomeRoutes.destinationOf(ScannerRoutes.root),
        AppDestination.qr,
      );
    });

    test('devolve null fora das abas', () {
      expect(HomeRoutes.destinationOf(HomeRoutes.root), isNull);
      expect(HomeRoutes.destinationOf('/login'), isNull);
    });
  });
}
