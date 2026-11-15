import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/presenter/widgets/kym_chip.dart';
import '../../domain/entities/store_summary.dart';

class StoreTile extends StatelessWidget {
  const StoreTile({super.key, required this.store, required this.onTap});

  final StoreSummary store;
  final VoidCallback onTap;

  String? get _details {
    final parts = [store.code, store.city].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String get _pendingLabel =>
      store.openOrders > 0 ? '${store.openOrders} em aberto' : 'Em dia';

  @override
  Widget build(BuildContext context) {
    final details = _details;

    return Semantics(
      button: true,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name, style: AppTextStyles.cardTitle),
                  if (details != null) ...[
                    const SizedBox(height: 2),
                    Text(details, style: AppTextStyles.metadata),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (!store.isActive)
                        const KymChip(
                          label: 'Inativa',
                          tone: KymChipTone.overdue,
                        ),
                      KymChip(
                        label: _pendingLabel,
                        tone: store.openOrders > 0
                            ? KymChipTone.pending
                            : KymChipTone.done,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
