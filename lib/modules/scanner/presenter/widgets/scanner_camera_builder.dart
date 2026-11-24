import 'package:flutter/widgets.dart';

/// Monta a câmera da tela. Os testes passam um fake, porque o scanner não
/// roda fora de um aparelho.
typedef ScannerCameraBuilder =
    Widget Function(
      BuildContext context, {
      required bool active,
      required ValueChanged<String> onDetect,
      required VoidCallback onOpenSettings,
    });
