import 'package:flutter_modular/flutter_modular.dart';

import '../auth/domain/entities/user_role.dart';
import '../auth/domain/entities/user_role_permissions.dart';
import '../auth/presenter/controllers/session_controller.dart';
import '../auth/presenter/guards/role_guard.dart';
import '../home/home_routes.dart';
import 'domain/services/app_settings_service.dart';
import 'domain/services/scan_feedback.dart';
import 'domain/services/scanned_code_handler.dart';
import 'domain/usecases/open_app_settings.dart';
import 'domain/usecases/process_scanned_code.dart';
import 'external/services/device_scan_feedback.dart';
import 'external/services/permission_handler_app_settings_service.dart';
import 'infra/services/pending_scanned_code_handler.dart';
import 'presenter/controllers/scanner_controller.dart';
import 'presenter/pages/scanner_page.dart';
import 'scanner_routes.dart';

/// Leitor de QR Code (tela 7), aberto pelo botão QR da barra inferior.
/// Só técnico e lojista entram; os outros perfis voltam à tela inicial.
class ScannerModule extends Module {
  ScannerModule({this.cameraBuilder});

  /// Troca a câmera real, para testes.
  final ScannerCameraBuilder? cameraBuilder;

  @override
  String? get path => ScannerRoutes.root;

  static UserRole? _currentRole() => inject<SessionController>().user?.role;

  @override
  void register(ModularContext c) {
    c
      ..addLazySingleton<ScanFeedback>(() => DeviceScanFeedback())
      ..addLazySingleton<AppSettingsService>(
        () => PermissionHandlerAppSettingsService(),
      )
      // B32 troca este registro pelo tratamento que redireciona.
      ..addLazySingleton<ScannedCodeHandler>(() => PendingScannedCodeHandler())
      ..addLazySingleton<ProcessScannedCode>(ProcessScannedCode.new)
      ..addLazySingleton<OpenAppSettings>(OpenAppSettings.new)
      ..route(
        '/',
        guards: [
          RoleGuard.forDestination(
            AppDestination.qr,
            currentRole: _currentRole,
            fallbackRoute: (role) => HomeRoutes.of(role.initialDestination),
          ).call,
        ],
        // O controller vive só enquanto o leitor estiver aberto.
        provide: (scoped) {
          scoped.addChangeNotifier<ScannerController>(ScannerController.new);
        },
        child: (context, _) => ScannerPage(
          onBack: () => context.pop(),
          showStoreLegend: _currentRole()?.canScanStoreQr ?? false,
          cameraBuilder: cameraBuilder,
        ),
      );
  }
}
