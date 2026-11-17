import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import 'scan_frame.dart';
import 'scanner_permission_denied.dart';
import 'scanner_unavailable.dart';

/// Câmera, moldura e lanterna. É o único widget que conhece o mobile_scanner,
/// por isso os testes da tela o substituem por um fake (ScannerCameraBuilder).
///
/// O mobile_scanner pede a permissão sozinho; a negação chega como erro do
/// controller e vira a tela de permissão negada.
class ScannerCameraView extends StatefulWidget {
  const ScannerCameraView({
    super.key,
    required this.active,
    required this.onDetect,
    required this.onOpenSettings,
  });

  /// Falso enquanto um código é tratado: a câmera para de ler.
  final bool active;

  final ValueChanged<String> onDetect;

  final VoidCallback onOpenSettings;

  @override
  State<ScannerCameraView> createState() => _ScannerCameraViewState();
}

class _ScannerCameraViewState extends State<ScannerCameraView>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _resumeOnForeground = false;
  bool _awaitingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ScannerCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    unawaited(widget.active ? _start() : _stop());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Voltar das configurações tenta de novo; voltar do diálogo de
        // permissão não, porque a câmera ainda nem tinha iniciado.
        final shouldStart = _resumeOnForeground || _awaitingSettings;
        _resumeOnForeground = false;
        _awaitingSettings = false;
        if (shouldStart && widget.active) unawaited(_start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_controller.value.isRunning) {
          _resumeOnForeground = true;
          unawaited(_stop());
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _start() async {
    try {
      await _controller.start();
    } catch (_) {
      // O erro já está em _controller.value.error e vira a tela de estado.
    }
  }

  Future<void> _stop() async {
    try {
      await _controller.stop();
    } catch (_) {}
  }

  void _openSettings() {
    _awaitingSettings = true;
    widget.onOpenSettings();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!widget.active) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        widget.onDetect(value);
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Liberar o controller solta a câmera ao sair da tela.
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          placeholderBuilder: (context) => const Center(
            child: CircularProgressIndicator(color: AppColors.scanFrame),
          ),
          errorBuilder: (context, error) =>
              error.errorCode == MobileScannerErrorCode.permissionDenied
              ? ScannerPermissionDenied(onOpenSettings: _openSettings)
              : const ScannerUnavailable(),
        ),
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (context, state, _) {
            if (state.error != null || !state.isRunning) {
              return const SizedBox.shrink();
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = (constraints.biggest.shortestSide * 0.7)
                          .clamp(160.0, 320.0);
                      return Center(
                        child: ScanFrame(size: side, animate: widget.active),
                      );
                    },
                  ),
                ),
                if (state.torchState != TorchState.unavailable)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _TorchButton(
                      isOn: state.torchState == TorchState.on,
                      onPressed: _toggleTorch,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.isOn, required this.onPressed});

  final bool isOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: isOn ? 'Desligar lanterna' : 'Ligar lanterna',
      onPressed: onPressed,
      isSelected: isOn,
      icon: const Icon(Icons.flash_off_rounded),
      selectedIcon: const Icon(Icons.flash_on_rounded),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppTheme.buttonHeight),
        backgroundColor: AppColors.darkPanel,
        foregroundColor: AppColors.darkText,
        iconSize: 24,
      ),
    );
  }
}
