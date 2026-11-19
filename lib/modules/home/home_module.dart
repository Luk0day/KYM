import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/presenter/widgets/kym_button.dart';
import '../auth/auth_routes.dart';
import '../auth/domain/entities/user_role.dart';
import '../auth/domain/entities/user_role_permissions.dart';
import '../auth/presenter/controllers/session_controller.dart';
import '../auth/presenter/guards/role_guard.dart';
import '../auth/presenter/utils/user_role_label.dart';
import '../equipment/presenter/controllers/equipment_detail_controller.dart';
import '../equipment/presenter/controllers/equipment_list_controller.dart';
import '../equipment/presenter/pages/equipment_detail_page.dart';
import '../stores/presenter/controllers/store_detail_controller.dart';
import '../stores/presenter/controllers/stores_controller.dart';
import '../stores/presenter/pages/store_detail_page.dart';
import '../stores/presenter/pages/stores_page.dart';
import 'home_routes.dart';
import 'presenter/pages/qr_scanner_placeholder_page.dart';
import 'presenter/pages/shell_page.dart';
import 'presenter/pages/tab_placeholder_page.dart';

class HomeModule extends Module {
  @override
  String? get path => HomeRoutes.root;

  static UserRole? _currentRole() => inject<SessionController>().user?.role;

  static String _initialRoute(UserRole role) =>
      HomeRoutes.of(role.initialDestination);

  static ModularGuard _guard(AppDestination destination) =>
      RoleGuard.forDestination(
        destination,
        currentRole: _currentRole,
        fallbackRoute: _initialRoute,
      ).call;

  static String? _authGuard(RouteState state) =>
      _currentRole() == null ? AuthRoutes.login : null;

  static String? _shellGuard(RouteState state) {
    final role = _currentRole();
    if (role == null) return AuthRoutes.login;
    final path = state.uri.path;
    if (path == HomeRoutes.root || path == '${HomeRoutes.root}/') {
      return _initialRoute(role);
    }
    return null;
  }

  @override
  void register(ModularContext c) {
    c
      ..route(
        HomeRoutes.qrPath,
        guards: [_guard(AppDestination.qr)],
        child: (context, _) =>
            QrScannerPlaceholderPage(onBack: () => context.pop()),
      )
      // Detalhe da loja (B26): por cima da casca, com voltar.
      ..route(
        HomeRoutes.lojaPath,
        guards: [_guard(AppDestination.lojas)],
        provide: (scoped) {
          scoped
            ..addChangeNotifier<StoreDetailController>(
              StoreDetailController.new,
            )
            ..addChangeNotifier<EquipmentListController>(
              EquipmentListController.new,
            );
        },
        child: (context, state) => StoreDetailPage(
          storeId: state.params['id']!,
          controller: context.read<StoreDetailController>(),
          equipmentController: context.read<EquipmentListController>(),
          canCheckIn: _currentRole()?.canCheckIn ?? false,
          onBack: () => context.pop(),
          onEquipmentSelected: (equipment) =>
              context.pushNamed(HomeRoutes.equipamento(equipment.id)),
        ),
      )
      // Detalhe do equipamento (B28): qualquer perfil logado; a lista da loja
      // e o leitor de QR (B32) chegam aqui pelo id.
      ..route(
        HomeRoutes.equipamentoPath,
        guards: [_authGuard],
        provide: (scoped) {
          scoped.addChangeNotifier<EquipmentDetailController>(
            EquipmentDetailController.new,
          );
        },
        child: (context, state) {
          final user = inject<SessionController>().user;
          return EquipmentDetailPage(
            equipmentId: state.params['id']!,
            controller: context.read<EquipmentDetailController>(),
            role: user?.role ?? UserRole.lojista,
            currentUserId: user?.id,
            onBack: () => context.pop(),
          );
        },
      )
      ..route(
        '/',
        guards: [_shellGuard],
        child: (context, _) => ShellPage(session: inject<SessionController>()),
        children: (c) => c
          ..route(
            HomeRoutes.painelPath,
            guards: [_guard(AppDestination.painel)],
            child: (context, _) {
              final user = inject<SessionController>().user;
              final name = user?.displayName ?? user?.email ?? '';
              return TabPlaceholderPage(
                title: 'Olá, ${name.split(' ').first}',
                subtitle: user?.role.label,
              );
            },
          )
          ..route(
            HomeRoutes.lojasPath,
            guards: [_guard(AppDestination.lojas)],
            // O controller vive só enquanto a aba estiver aberta.
            provide: (scoped) {
              scoped.addChangeNotifier<StoresController>(StoresController.new);
            },
            child: (context, _) => StoresPage(
              controller: context.read<StoresController>(),
              onStoreSelected: (store) =>
                  context.pushNamed(HomeRoutes.loja(store.id)),
            ),
          )
          ..route(
            HomeRoutes.agendaPath,
            guards: [_guard(AppDestination.agenda)],
            child: (context, _) => const TabPlaceholderPage(title: 'Agenda'),
          )
          ..route(
            HomeRoutes.qrCodesPath,
            guards: [_guard(AppDestination.qrCodes)],
            child: (context, _) => const TabPlaceholderPage(
              title: 'QR Codes',
              subtitle: 'Gere e imprima as etiquetas para campo',
            ),
          )
          ..route(
            HomeRoutes.perfilPath,
            guards: [_guard(AppDestination.perfil)],
            child: (context, _) => TabPlaceholderPage(
              title: 'Perfil',
              subtitle: 'Configurações operacionais e conta',
              children: [
                KymButton(
                  label: 'Sair da conta',
                  variant: KymButtonVariant.soft,
                  leading: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () async {
                    await inject<SessionController>().signOut();
                    if (context.mounted) context.navigate(AuthRoutes.login);
                  },
                ),
              ],
            ),
          ),
      );
  }
}
