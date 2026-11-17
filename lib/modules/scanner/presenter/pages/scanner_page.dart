import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/presenter/widgets/kym_banner.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../controllers/scanner_controller.dart';
import '../widgets/scanner_camera_view.dart';

/// Monta a câmera da tela. Os testes passam um fake, porque o scanner não
/// roda fora de um aparelho.
typedef ScannerCameraBuilder =
    Widget Function(
      BuildContext context, {
      required bool active,
      required ValueChanged<String> onDetect,
      required VoidCallback onOpenSettings,
    });

class ScannerPage extends StatefulWidget {
  const ScannerPage({
    super.key,
    required this.onBack,
    required this.showStoreLegend,
    this.controller,
    this.cameraBuilder,
  });

  final VoidCallback onBack;

  /// A legenda do QR da loja é só do técnico (check-in e check-out).
  final bool showStoreLegend;

  /// Sem controller, usa o que o módulo registrou para a rota.
  final ScannerController? controller;

  final ScannerCameraBuilder? cameraBuilder;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late final ScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? context.read<ScannerController>();
  }

  Widget _buildCamera(BuildContext context, bool active) {
    final builder = widget.cameraBuilder;
    if (builder != null) {
      return builder(
        context,
        active: active,
        onDetect: _controller.onDetect,
        onOpenSettings: _controller.openSettings,
      );
    }
    return ScannerCameraView(
      active: active,
      onDetect: _controller.onDetect,
      onOpenSettings: _controller.openSettings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkText,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: widget.onBack,
        ),
        title: Text(
          'Leitor de QR Code',
          style: AppTextStyles.sectionTitle.copyWith(color: AppColors.darkText),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => Column(
          children: [
            Expanded(
              child: _buildCamera(context, _controller.isCameraActive),
            ),
            _InfoPanel(
              controller: _controller,
              showStoreLegend: widget.showStoreLegend,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.controller, required this.showStoreLegend});

  final ScannerController controller;
  final bool showStoreLegend;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    final handled = controller.status == ScannerStatus.handled;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.darkPanel,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: handled
              ? _HandledContent(
                  code: controller.lastCode ?? '',
                  onReadAgain: controller.resume,
                )
              : _LegendContent(
                  showStoreLegend: showStoreLegend,
                  failed: controller.lastReadFailed,
                  processing: controller.status == ScannerStatus.processing,
                ),
        ),
      ),
    );
  }
}

class _LegendContent extends StatelessWidget {
  const _LegendContent({
    required this.showStoreLegend,
    required this.failed,
    required this.processing,
  });

  final bool showStoreLegend;
  final bool failed;
  final bool processing;

  @override
  Widget build(BuildContext context) {
    final target = showStoreLegend
        ? 'da loja ou do equipamento'
        : 'do equipamento';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (failed) ...[
          const KymBanner(
            message: 'Não foi possível tratar este código. Tente ler de novo.',
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Aponte a câmera para o QR Code $target',
                style: AppTextStyles.cardTitle.copyWith(
                  color: AppColors.darkText,
                ),
              ),
            ),
            if (processing)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.scanFrame,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (showStoreLegend) ...[
          const _LegendItem(
            icon: Icons.storefront_outlined,
            text: 'QR da loja → check-in / check-out',
          ),
          const SizedBox(height: 12),
        ],
        const _LegendItem(
          icon: Icons.precision_manufacturing_outlined,
          text: 'QR do equipamento → abre os detalhes',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ExcludeSemantics(child: Icon(icon, color: AppColors.scanFrame)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(color: AppColors.darkText),
          ),
        ),
      ],
    );
  }
}

class _HandledContent extends StatelessWidget {
  const _HandledContent({required this.code, required this.onReadAgain});

  final String code;
  final VoidCallback onReadAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Código lido',
                style: AppTextStyles.cardTitle.copyWith(
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                code,
                style: AppTextStyles.body.copyWith(color: AppColors.darkText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KymButton(label: 'Ler outro código', onPressed: onReadAgain),
      ],
    );
  }
}
