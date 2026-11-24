import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../shared/presenter/widgets/kym_button.dart';
import '../agenda/domain/usecases/build_agenda.dart';
import '../agenda/domain/usecases/watch_agenda.dart';
import '../agenda/presenter/controllers/agenda_controller.dart';
import '../agenda/presenter/pages/agenda_page.dart';
import '../agenda/presenter/utils/agenda_clock.dart';
import '../auth/auth_routes.dart';
import '../auth/domain/entities/authenticated_user.dart';
import '../auth/domain/entities/user_role.dart';
import '../auth/domain/entities/user_role_permissions.dart';
import '../auth/presenter/controllers/session_controller.dart';
import '../auth/presenter/guards/role_guard.dart';
import '../auth/presenter/utils/user_role_label.dart';
import '../stores/presenter/controllers/stores_controller.dart';
import '../stores/presenter/pages/stores_page.dart';
import 'home_routes.dart';
import 'presenter/pages/shell_page.dart';
import 'presenter/pages/tab_placeholder_page.dart';

class HomeModule extends Module {
  @override
  String? get path => HomeRoutes.root;

  static UserRole? _currentRole() => inject<SessionController>().user?.role;

  static AuthenticatedUser _currentUser() => inject<SessionController>().user!;

  static String _initialRoute(UserRole role) =>
      HomeRoutes.of(role.initialDestination);

  static ModularGuard _guard(AppDestination destination) =>
      RoleGuard.forDestination(
        destination,
        currentRole: _currentRole,
        fallbackRoute: _initialRoute,
      ).call;

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
    c.route(
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
            // TODO(B26): abrir os detalhes da loja.
            onStoreSelected: (_) {},
          ),
        )
        ..route(
          HomeRoutes.agendaPath,
          guards: [_guard(AppDestination.agenda)],
          provide: (scoped) {
            scoped.addChangeNotifier<AgendaController>(
              (
                WatchAgenda watch,
                BuildAgenda build,
                AgendaFilterMemory memory,
                AgendaClock clock,
              ) => AgendaController(
                watch,
                build,
                memory,
                _currentUser(),
                clock: clock.now,
              ),
            );
          },
          child: (context, _) => const AgendaPage(),
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
