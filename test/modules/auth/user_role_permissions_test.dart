import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/auth/domain/entities/user_role_permissions.dart';

void main() {
  group('destinos por perfil', () {
    test('técnico: Painel, Lojas, QR, Agenda e Perfil', () {
      expect(UserRole.tecnico.destinations, [
        AppDestination.painel,
        AppDestination.lojas,
        AppDestination.qr,
        AppDestination.agenda,
        AppDestination.perfil,
      ]);
    });

    test('gestor: Painel, Lojas, Agenda, QR Codes e Perfil', () {
      expect(UserRole.gestor.destinations, [
        AppDestination.painel,
        AppDestination.lojas,
        AppDestination.agenda,
        AppDestination.qrCodes,
        AppDestination.perfil,
      ]);
    });

    test('lojista: Lojas, QR e Perfil', () {
      expect(UserRole.lojista.destinations, [
        AppDestination.lojas,
        AppDestination.qr,
        AppDestination.perfil,
      ]);
    });

    test('todo perfil tem Lojas e Perfil', () {
      for (final role in UserRole.values) {
        expect(role.canAccess(AppDestination.lojas), isTrue, reason: '$role');
        expect(role.canAccess(AppDestination.perfil), isTrue, reason: '$role');
      }
    });
  });

  group('aba inicial', () {
    test('técnico e gestor abrem no Painel', () {
      expect(UserRole.tecnico.initialDestination, AppDestination.painel);
      expect(UserRole.gestor.initialDestination, AppDestination.painel);
    });

    test('lojista abre em Lojas', () {
      expect(UserRole.lojista.initialDestination, AppDestination.lojas);
    });

    test('a aba inicial sempre é um destino permitido', () {
      for (final role in UserRole.values) {
        expect(role.canAccess(role.initialDestination), isTrue);
      }
    });
  });

  group('permissões de ação', () {
    final matrix = <String, (bool Function(UserRole), List<bool>)>{
      'canViewDashboard': ((r) => r.canViewDashboard, [true, true, false]),
      'canViewAgenda': ((r) => r.canViewAgenda, [true, true, false]),
      'canScanQr': ((r) => r.canScanQr, [true, false, true]),
      'canManageQrCodes': ((r) => r.canManageQrCodes, [false, true, false]),
      'canOpenCorrective': ((r) => r.canOpenCorrective, [true, true, true]),
      'canCheckIn': ((r) => r.canCheckIn, [true, false, false]),
      'canRegisterMaintenance': (
        (r) => r.canRegisterMaintenance,
        [true, false, false],
      ),
      'canEditStores': ((r) => r.canEditStores, [false, true, false]),
      'canEditEquipment': ((r) => r.canEditEquipment, [false, true, false]),
      'canScheduleMaintenance': (
        (r) => r.canScheduleMaintenance,
        [false, true, false],
      ),
      'canTriageOrders': ((r) => r.canTriageOrders, [false, true, false]),
    };

    const roles = [UserRole.tecnico, UserRole.gestor, UserRole.lojista];

    for (final entry in matrix.entries) {
      for (var i = 0; i < roles.length; i++) {
        final role = roles[i];
        final expected = entry.value.$2[i];
        test('${entry.key} para ${role.name} é $expected', () {
          expect(entry.value.$1(role), expected);
        });
      }
    }
  });
}
