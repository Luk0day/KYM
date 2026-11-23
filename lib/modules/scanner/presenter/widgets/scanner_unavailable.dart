import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// Câmera indisponível: aparelho sem câmera ou emulador sem câmera simulada.
class ScannerUnavailable extends StatelessWidget {
  const ScannerUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.videocam_off_outlined,
                  size: 56,
                  color: AppColors.scanFrame,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Câmera indisponível',
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Não foi possível usar a câmera deste aparelho. Em emulador, '
                'ative a câmera simulada ou teste em um aparelho real.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.darkText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
