import 'package:permission_handler/permission_handler.dart' as ph;

import '../../domain/services/app_settings_service.dart';

/// O permission_handler só serve para este botão: quem pede a permissão da
/// câmera é o próprio mobile_scanner.
class PermissionHandlerAppSettingsService implements AppSettingsService {
  PermissionHandlerAppSettingsService({Future<bool> Function()? opener})
    : _opener = opener ?? ph.openAppSettings;

  final Future<bool> Function() _opener;

  @override
  Future<bool> open() => _opener();
}
