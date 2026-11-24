import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_chip.dart';
import '../../../orders/domain/entities/maintenance_order.dart';
import '../../domain/entities/equipment_list_item.dart';
import '../../domain/entities/equipment_status.dart';
import '../utils/equipment_messages.dart';
import 'equipment_status_chip.dart';

/// Item da lista de equipamentos da loja (Figma: iniciais, nome, última
/// manutenção e um selo à direita).
class EquipmentTile extends StatelessWidget {
  const EquipmentTile({super.key, required this.item, required this.onTap});

  final EquipmentListItem item;
  final VoidCallback onTap;

  bool get _urgent =>
      item.hasOverdueOrder || item.nextOrderType == OrderType.corretiva;

  /// Situação fora do normal só vira texto quando o selo já mostra a ordem.
  String? get _statusNote =>
      item.hasOpenOrder && item.equipment.status != EquipmentStatus.operando
      ? equipmentStatusLabel(item.equipment.status)
      : null;

  String get _subtitle =>
      [?_statusNote, lastMaintenanceLabel(item.lastMaintenanceAt)].join(' · ');

  @override
  Widget build(BuildContext context) {
    final e = item.equipment;
    final type = item.nextOrderType;

    return Semantics(
      button: true,
      onTap: onTap,
      label: [
        e.name,
        if (type != null)
          '${orderTypeLabel(type)} em aberto'
        else
          equipmentStatusLabel(e.status),
        if (item.hasOverdueOrder) 'atrasada',
        _subtitle,
      ].join('. '),
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
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _Initials(
                      text: equipmentInitials(e.serialNumber, e.name),
                      urgent: _urgent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle,
                          ),
                          Text(
                            _subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.metadata,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (type != null)
                      KymChip(
                        label: orderTypeLabel(type),
                        tone: type == OrderType.corretiva
                            ? KymChipTone.overdue
                            : KymChipTone.pending,
                      )
                    else
                      EquipmentStatusChip(status: e.status),
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

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.urgent});

  final String text;
  final bool urgent;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: urgent ? AppColors.overdueBg : AppColors.equipmentTileBg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: AppTextStyles.cardTitle.copyWith(
        fontSize: 18,
        color: urgent ? AppColors.overdueFg : AppColors.primary,
      ),
    ),
  );
}
