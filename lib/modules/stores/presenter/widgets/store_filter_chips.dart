import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../domain/entities/store_filter.dart';
import '../utils/stores_messages.dart';

/// Chips de filtro em linha, com rolagem horizontal (Todas, Com atrasadas...).
class StoreFilterChips extends StatelessWidget {
  const StoreFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final StoreFilterKind selected;
  final ValueChanged<StoreFilterKind> onSelected;

  @override
  Widget build(BuildContext context) {
    const kinds = StoreFilterKind.values;
    // A linha cresce com a fonte do sistema para o texto não ser cortado.
    final height = MediaQuery.textScalerOf(context).scale(44).clamp(48.0, 96.0);

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kinds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final kind = kinds[index];
          return _FilterChip(
            label: kind.label,
            selected: kind == selected,
            onTap: () => onSelected(kind),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
      child: Center(
        child: Material(
          color: selected ? AppColors.primary : AppColors.surface,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.surface
                          : AppColors.textSecondary,
                    ),
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
