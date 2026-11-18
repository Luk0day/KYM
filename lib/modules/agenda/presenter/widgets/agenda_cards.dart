import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/presenter/widgets/kym_chip.dart';
import '../../../orders/domain/entities/agenda_item.dart';
import '../../../orders/domain/entities/maintenance_order.dart';
import '../../../orders/domain/entities/order_situation.dart';
import '../../domain/entities/agenda_section.dart';
import '../utils/agenda_dates.dart';

String initialsOf(String text) {
  final words = text
      .split(RegExp(r'[\s-]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  final first = words.first[0];
  final second = words.length > 1 ? words[1][0] : '';
  return (first + second).toUpperCase();
}

class AgendaInitialsTile extends StatelessWidget {
  const AgendaInitialsTile({
    super.key,
    required this.text,
    this.warm = false,
    this.size = 44,
  });

  final String text;
  final bool warm;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: warm ? AppColors.overdueBg : AppColors.equipmentTileBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Center(
            child: MediaQuery.withNoTextScaling(
              child: Text(
                initialsOf(text),
                style: AppTextStyles.cardTitle.copyWith(
                  color: warm ? AppColors.accent : AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AgendaGreetingCard extends StatelessWidget {
  const AgendaGreetingCard({
    super.key,
    required this.name,
    required this.summary,
  });

  final String name;
  final AgendaSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.scheduledToday;
    final done = summary.doneToday;
    final visits = total == 1
        ? '1 visita programada hoje'
        : '$total visitas programadas hoje';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          AgendaInitialsTile(text: name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Olá, $name', style: AppTextStyles.cardTitle),
                const SizedBox(height: 2),
                Text(visits, style: AppTextStyles.metadata),
              ],
            ),
          ),
          if (total > 0)
            Semantics(
              container: true,
              label: '$done de $total visitas de hoje concluídas',
              excludeSemantics: true,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: done / total,
                      strokeWidth: 3,
                      color: AppColors.doneFg,
                      backgroundColor: AppColors.inactive,
                    ),
                    MediaQuery.withNoTextScaling(
                      child: Text(
                        '$done/$total',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textPrimary,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AgendaSectionHeader extends StatelessWidget {
  const AgendaSectionHeader({
    super.key,
    required this.section,
    required this.today,
  });

  final AgendaSection section;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final overdue = section.kind == AgendaSectionKind.emAtraso;
    final (icon, title) = switch (section.kind) {
      AgendaSectionKind.semData => (Icons.event_busy_outlined, 'Sem data'),
      AgendaSectionKind.emAtraso => (Icons.warning_amber_rounded, 'Em atraso'),
      AgendaSectionKind.dia => (
        Icons.calendar_today_outlined,
        AgendaDates.relative(section.day!, today),
      ),
    };
    final count = section.items.length;
    final countLabel = count == 1 ? '1 visita' : '$count visitas';

    return Semantics(
      header: true,
      label: '$title, $countLabel',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: overdue ? AppColors.accent : AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
            Text(
              countLabel.toUpperCase(),
              textScaler: MediaQuery.textScalerOf(context)
                  .clamp(maxScaleFactor: 1.3),
              style: AppTextStyles.label.copyWith(
                color: overdue ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AgendaOrderCard extends StatelessWidget {
  const AgendaOrderCard({super.key, required this.item, required this.today});

  final AgendaItem item;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final order = item.order;
    final situation = order.situationOn(today);
    final corrective = order.type == OrderType.corretiva;
    final date = order.scheduledFor ?? order.completedAt;
    final when = date == null
        ? 'Sem data'
        : AgendaDates.shortRelative(date, today);
    final (situationLabel, situationTone) = switch (situation) {
      OrderSituation.atrasada => ('Atrasada', KymChipTone.overdue),
      OrderSituation.concluida => ('Concluída', KymChipTone.done),
      _ => ('Pendente', KymChipTone.pending),
    };
    final typeLabel = corrective ? 'Corretiva' : 'Preventiva';
    final description = order.description?.trim();

    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AgendaInitialsTile(
                  text: item.equipmentName,
                  warm: corrective || situation == OrderSituation.atrasada,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.equipmentName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.cardTitle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.storeName} · $when',
                        style: AppTextStyles.metadata,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      KymChip(label: typeLabel, tone: KymChipTone.neutral),
                      const SizedBox(height: 6),
                      KymChip(label: situationLabel, tone: situationTone),
                    ],
                  ),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metadata,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
