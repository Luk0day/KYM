import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../controllers/stores_controller.dart';
import '../utils/stores_messages.dart';

/// Selo "● Sincronizado" do topo da tela.
class SyncStatusPill extends StatelessWidget {
  const SyncStatusPill({super.key, required this.indicator});

  final SyncIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (indicator) {
      SyncIndicator.synced => (AppColors.doneBg, AppColors.doneFg),
      SyncIndicator.unknown ||
      SyncIndicator.offline => (AppColors.inactive, AppColors.textSecondary),
      SyncIndicator.failed => (AppColors.overdueBg, AppColors.overdueFg),
    };

    return Semantics(
      label: 'Sincronização: ${indicator.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                indicator.label,
                style: AppTextStyles.label.copyWith(
                  color: foreground,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
