import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../modules/auth/presenter/controllers/password_recovery_controller.dart';
import '../modules/auth/presenter/widgets/password_recovery_listener.dart';
import 'theme/app_theme.dart';

class KymApp extends StatelessWidget {
  const KymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KYM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ModularApp.routerConfigOf(context),
      builder: (context, child) => PasswordRecoveryListener(
        controller: inject<PasswordRecoveryController>(),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
