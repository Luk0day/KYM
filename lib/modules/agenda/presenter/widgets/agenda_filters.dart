import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../orders/domain/entities/order_situation.dart';
import '../utils/agenda_dates.dart';

class AgendaDayStrip extends StatefulWidget {
  const AgendaDayStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.today,
    required this.onSelected,
  });

  static const double _itemWidth = 52;

  static Key keyFor(DateTime day) =>
      ValueKey('agenda-day-${day.year}-${day.month}-${day.day}');
  static const double _gap = 8;

  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelected;

  @override
  State<AgendaDayStrip> createState() => _AgendaDayStripState();
}

class _AgendaDayStripState extends State<AgendaDayStrip> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final index = widget.days.indexWhere(
      (d) => dateOnly(d) == dateOnly(widget.selected),
    );
    final weekday = widget.selected.weekday;
    final first = index < 0
        ? 0
        : index - (weekday >= DateTime.saturday ? 4 : weekday - 1);
    _scroll = ScrollController(
      initialScrollOffset:
          first.clamp(0, widget.days.length) *
          (AgendaDayStrip._itemWidth + AgendaDayStrip._gap),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.days.length,
        separatorBuilder: (_, _) => const SizedBox(width: AgendaDayStrip._gap),
        itemBuilder: (context, index) {
          final day = widget.days[index];
          return _DayBox(
            key: AgendaDayStrip.keyFor(day),
            day: day,
            selected: dateOnly(day) == dateOnly(widget.selected),
            isToday: dateOnly(day) == dateOnly(widget.today),
            onTap: () => widget.onSelected(day),
          );
        },
      ),
    );
  }
}

class _DayBox extends StatelessWidget {
  const _DayBox({
    super.key,
    required this.day,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.textPrimary;
    final label =
        '${AgendaDates.weekday(day)}, ${AgendaDates.dayMonth(day)}'
        '${isToday ? ', hoje' : ''}';

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: AgendaDayStrip._itemWidth,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AgendaDates.weekdayShort(day),
                    style: AppTextStyles.metadata.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (selected)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
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

class AgendaChipOption<T> {
  const AgendaChipOption(this.value, this.label);

  final T value;
  final String label;
}

class AgendaChipRow<T> extends StatelessWidget {
  const AgendaChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.semanticsLabel,
  });

  final List<AgendaChipOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _AgendaChip(
                  label: option.label,
                  selected: option.value == selected,
                  onTap: () => onSelected(option.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgendaChip extends StatelessWidget {
  const _AgendaChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: AppTextStyles.label.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
