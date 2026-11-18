import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

enum KymChipTone { pending, overdue, done, neutral }

class KymChip extends StatelessWidget {
  const KymChip({super.key, required this.label, required this.tone});

  final String label;
  final KymChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      KymChipTone.pending => (AppColors.pendingBg, AppColors.pendingFg),
      KymChipTone.overdue => (AppColors.overdueBg, AppColors.overdueFg),
      KymChipTone.done => (AppColors.doneBg, AppColors.doneFg),
      KymChipTone.neutral => (AppColors.equipmentTileBg, AppColors.primary),
    };

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.label.copyWith(color: foreground),
      ),
    );
  }
}
