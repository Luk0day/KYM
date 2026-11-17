import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_chip.dart';
import '../../domain/entities/equipment_list_item.dart';
import '../utils/equipment_messages.dart';
import 'equipment_status_chip.dart';

class EquipmentTile extends StatelessWidget {
  const EquipmentTile({super.key, required this.item, required this.onTap});

  final EquipmentListItem item;
  final VoidCallback onTap;

  String? get _subtitle {
    final e = item.equipment;
    final parts = [e.category, e.brand, e.model]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final e = item.equipment;
    final subtitle = _subtitle;
    final initials = categoryInitials(e.category);
    final orderLabel = item.hasOpenOrder
        ? openOrdersLabel(item.openOrders, item.overdueOrders)
        : null;

    return Semantics(
      button: true,
      onTap: onTap,
      label: [e.name, equipmentStatusLabel(e.status), ?orderLabel].join('. '),
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.equipmentTileBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: initials.isEmpty
                          ? const Icon(
                              Icons.settings_outlined,
                              color: AppColors.primary,
                            )
                          : Text(
                              initials,
                              style: AppTextStyles.cardTitle.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.name, style: AppTextStyles.cardTitle),
                          if (subtitle != null)
                            Text(subtitle, style: AppTextStyles.metadata),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              EquipmentStatusChip(status: e.status),
                              if (orderLabel != null)
                                KymChip(
                                  label: orderLabel,
                                  tone: item.hasOverdueOrder
                                      ? KymChipTone.overdue
                                      : KymChipTone.pending,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
