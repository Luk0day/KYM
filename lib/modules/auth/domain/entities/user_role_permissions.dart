import 'user_role.dart';

enum AppDestination { painel, lojas, qr, agenda, qrCodes, perfil }

extension UserRolePermissions on UserRole {
  List<AppDestination> get destinations => switch (this) {
    UserRole.tecnico => const [
      AppDestination.painel,
      AppDestination.lojas,
      AppDestination.qr,
      AppDestination.agenda,
      AppDestination.perfil,
    ],
    UserRole.gestor => const [
      AppDestination.painel,
      AppDestination.lojas,
      AppDestination.agenda,
      AppDestination.qrCodes,
      AppDestination.perfil,
    ],
    UserRole.lojista => const [
      AppDestination.lojas,
      AppDestination.qr,
      AppDestination.perfil,
    ],
  };

  AppDestination get initialDestination => switch (this) {
    UserRole.tecnico || UserRole.gestor => AppDestination.painel,
    UserRole.lojista => AppDestination.lojas,
  };

  bool canAccess(AppDestination destination) =>
      destinations.contains(destination);

  bool get canViewDashboard => canAccess(AppDestination.painel);

  bool get canViewAgenda => canAccess(AppDestination.agenda);

  bool get canScanQr => canAccess(AppDestination.qr);

  /// O QR da loja faz check-in e check-out, que é do técnico; o lojista só lê
  /// o QR do equipamento.
  bool get canScanStoreQr => canScanQr && this == UserRole.tecnico;

  bool get canManageQrCodes => canAccess(AppDestination.qrCodes);

  /// Todos os perfis abrem chamado corretivo, como na RLS de
  /// maintenance_orders (B05).
  bool get canOpenCorrective => true;

  bool get canCheckIn => this == UserRole.tecnico;

  bool get canRegisterMaintenance => this == UserRole.tecnico;

  bool get canEditStores => this == UserRole.gestor;

  bool get canScheduleMaintenance => this == UserRole.gestor;

  bool get canTriageOrders => this == UserRole.gestor;
}
