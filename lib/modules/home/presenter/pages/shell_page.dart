import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_bottom_nav_bar.dart';
import '../../../auth/domain/entities/user_role_permissions.dart';
import '../../../auth/presenter/controllers/session_controller.dart';
import '../../home_routes.dart';
import '../navigation/destination_nav_item.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key, required this.session});

  static const double railBreakpoint = 600;

  final SessionController session;

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  final _outletKey = GlobalKey<RouterOutletState>();

  void _open(AppDestination destination) {
    final route = HomeRoutes.of(destination);
    if (destination == AppDestination.qr) {
      context.pushNamed(route);
      return;
    }
    _outletKey.currentState?.navigate(route);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        final role = widget.session.user?.role;
        if (role == null) return const Scaffold();

        final destinations = role.destinations;
        final current = HomeRoutes.destinationOf(context.routeState().uri.path);
        final selectedIndex = current == null
            ? null
            : destinations.indexOf(current);
        final wide =
            MediaQuery.sizeOf(context).width >= ShellPage.railBreakpoint;

        final outlet = RouterOutlet(key: _outletKey);

        if (!wide) {
          return Scaffold(
            body: outlet,
            bottomNavigationBar: KymBottomNavBar(
              items: [for (final d in destinations) d.navItem],
              selectedIndex: selectedIndex,
              onSelected: (i) => _open(destinations[i]),
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _Rail(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelected: (i) => _open(destinations[i]),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: outlet),
            ],
          ),
        );
      },
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: NavigationRail(
        backgroundColor: AppColors.surface,
        useIndicator: false,
        groupAlignment: 0,
        labelType: NavigationRailLabelType.all,
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.textSecondary,
        ),
        selectedLabelTextStyle: AppTextStyles.navLabel.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: AppTextStyles.navLabel,
        destinations: [
          for (final d in destinations)
            NavigationRailDestination(
              icon: d.navItem.prominent
                  ? Tooltip(
                      message: d.navItem.tooltip ?? d.navItem.label,
                      child: KymProminentNavIcon(item: d.navItem, size: 48),
                    )
                  : Icon(d.navItem.icon),
              label: Text(d.navItem.label),
            ),
        ],
      ),
    );
  }
}
