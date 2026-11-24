import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';

/// Explica por que a câmera é necessária e leva às configurações do sistema.
class ScannerPermissionDenied extends StatelessWidget {
  const ScannerPermissionDenied({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.no_photography_outlined,
                size: 56,
                color: AppColors.scanFrame,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Precisamos da câmera',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O KYM usa a câmera para ler o QR Code da loja ou do '
              'equipamento. Libere o acesso nas configurações do aparelho e '
              'volte para continuar.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.darkText),
            ),
            const SizedBox(height: 24),
            KymButton(
              label: 'Abrir configurações',
              leading: const Icon(Icons.settings_outlined, size: 20),
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}
