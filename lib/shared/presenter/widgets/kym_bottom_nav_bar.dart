import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme.dart';

class KymNavItem {
  const KymNavItem({
    required this.icon,
    required this.label,
    this.tooltip,
    this.prominent = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final bool prominent;
  final String? badge;
}

/// Barra inferior do Figma. Quando há um item de destaque (o QR), a barra
/// reserva [prominentOverhang] acima da linha para o círculo, assim a parte
/// do círculo que sobe além da barra também recebe toque.
class KymBottomNavBar extends StatelessWidget {
  const KymBottomNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double height = 64;
  static const double prominentOverhang = 22;

  final List<KymNavItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final overhang = items.any((item) => item.prominent)
        ? prominentOverhang
        : 0.0;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Stack(
        children: [
          Positioned.fill(
            top: overhang,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: overhang + height,
              child: Row(
                // Sem o stretch o item de destaque encolhe para a altura do
                // círculo e o rótulo, preso à base do Stack, cai dentro dele.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: items[i].prominent
                          ? _ProminentItem(
                              item: items[i],
                              onTap: () => onSelected(i),
                            )
                          : Padding(
                              padding: EdgeInsets.only(top: overhang),
                              child: _NavItem(
                                item: items[i],
                                selected: i == selectedIndex,
                                onTap: () => onSelected(i),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final KymNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.navLabel.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProminentItem extends StatelessWidget {
  const _ProminentItem({required this.item, required this.onTap});

  static const double _size = 56;

  final KymNavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.tooltip ?? item.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: item.tooltip ?? item.label,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              KymProminentNavIcon(item: item),
              Positioned(
                left: 0,
                right: 0,
                bottom: 6,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.navLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KymProminentNavIcon extends StatelessWidget {
  const KymProminentNavIcon({
    super.key,
    required this.item,
    this.size = _ProminentItem._size,
  });

  static const double _iconRatio = 0.4;

  final KymNavItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: AppTheme.accentShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: AppColors.onAccent, size: size * _iconRatio),
          if (item.badge != null)
            Text(item.badge!, style: AppTextStyles.navBadge),
        ],
      ),
    );
  }
}
