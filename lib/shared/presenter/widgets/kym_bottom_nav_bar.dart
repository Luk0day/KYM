import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

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

class KymBottomNavBar extends StatelessWidget {
  const KymBottomNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double height = 64;

  final List<KymNavItem> items;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: items[i].prominent
                        ? _ProminentItem(
                            item: items[i],
                            onTap: () => onSelected(i),
                          )
                        : _NavItem(
                            item: items[i],
                            selected: i == selectedIndex,
                            onTap: () => onSelected(i),
                          ),
                  ),
              ],
            ),
          ),
        ),
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
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(top: -22, child: KymProminentNavIcon(item: item)),
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

  final KymNavItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: Colors.white, size: size * 0.4),
          if (item.badge != null)
            Text(
              item.badge!,
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontSize: 8,
                letterSpacing: 0.4,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }
}
