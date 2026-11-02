import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme.dart';

enum KymBannerType { error, success }

class KymBanner extends StatelessWidget {
  const KymBanner({
    super.key,
    required this.message,
    this.type = KymBannerType.error,
  });

  final String message;
  final KymBannerType type;

  @override
  Widget build(BuildContext context) {
    final isError = type == KymBannerType.error;

    // A mensagem usa o texto principal; só o ícone carrega a cor semântica,
    // porque coral sobre pêssego tem pouco contraste para leitura.
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? AppColors.overdueBg : AppColors.doneBg,
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 20,
              color: isError ? AppColors.overdueFg : AppColors.doneFg,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: AppTextStyles.body)),
          ],
        ),
      ),
    );
  }
}
