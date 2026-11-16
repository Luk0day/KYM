import 'package:flutter/material.dart';

import '../../../../shared/presenter/widgets/kym_bottom_nav_bar.dart';
import '../../../auth/domain/entities/user_role_permissions.dart';

extension DestinationNavItem on AppDestination {
  KymNavItem get navItem => switch (this) {
    AppDestination.painel => const KymNavItem(
      icon: Icons.grid_view_outlined,
      label: 'Painel',
    ),
    AppDestination.lojas => const KymNavItem(
      icon: Icons.home_outlined,
      label: 'Lojas',
    ),
    AppDestination.qr => const KymNavItem(
      icon: Icons.qr_code_2,
      label: 'Escanear',
      tooltip: 'Escanear QR Code',
      prominent: true,
      badge: 'QR',
    ),
    AppDestination.agenda => const KymNavItem(
      icon: Icons.calendar_today_outlined,
      label: 'Agenda',
    ),
    AppDestination.qrCodes => const KymNavItem(
      icon: Icons.qr_code_2,
      label: 'QR Codes',
    ),
    AppDestination.perfil => const KymNavItem(
      icon: Icons.person_outline,
      label: 'Perfil',
    ),
  };
}
