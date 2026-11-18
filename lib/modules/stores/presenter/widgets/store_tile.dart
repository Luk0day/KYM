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

  static const _linkWords = {'de', 'da', 'do', 'das', 'dos', 'e'};

  /// "Loja Centro" -> "LC"; ignora ligações ("Pão de Açúcar" -> "PA"). Nome de
  /// uma palavra só usa as duas primeiras letras.
  static String initialsOf(String name) {
    final all = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final significant = all
        .where((w) => !_linkWords.contains(w.toLowerCase()))
        .toList();
    final list = significant.isEmpty ? all.toList() : significant;
    if (list.isEmpty) {
      return '?';
    }
    if (list.length == 1) {
      final word = list.first;
      return word.substring(0, word.length < 2 ? 1 : 2).toUpperCase();
    }
    return '${list[0][0]}${list[1][0]}'.toUpperCase();
  }

  String? get _subtitle {
    final parts = [store.address, store.city].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  ({String label, KymChipTone tone}) get _status {
    if (store.overdueOrders > 0) {
      final n = store.overdueOrders;
      return (
        label: n == 1 ? '1 atrasada' : '$n atrasadas',
        tone: KymChipTone.overdue,
      );
    }
    if (store.openOrders > 0) {
      return (
        label: '${store.openOrders} em aberto',
        tone: KymChipTone.pending,
      );
    }
    return (label: 'Em dia', tone: KymChipTone.done);
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle;
    final status = _status;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final chips = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        KymChip(label: status.label, tone: status.tone),
        if (!store.isActive) ...[
          const SizedBox(height: 6),
          const KymChip(label: 'Inativa', tone: KymChipTone.neutral),
        ],
      ],
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(store.name, style: AppTextStyles.cardTitle),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: largeText ? 3 : 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.metadata,
          ),
        ],
      ],
    );

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
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Avatar(store: store),
                            const SizedBox(width: 14),
                            Expanded(child: info),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerLeft, child: chips),
                      ],
                    )
                  : Row(
                      children: [
                        _Avatar(store: store),
                        const SizedBox(width: 14),
                        Expanded(child: info),
                        const SizedBox(width: 10),
                        chips,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.store});

  final StoreSummary store;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = store.overdueOrders > 0
        ? (AppColors.overdueBg, AppColors.accent)
        : store.isActive
        ? (AppColors.equipmentTileBg, AppColors.primary)
        : (AppColors.inactive, AppColors.textSecondary);

    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          StoreTile.initialsOf(store.name),
          maxLines: 1,
          style: AppTextStyles.cardTitle.copyWith(
            color: foreground,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}
