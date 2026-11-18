import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';

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
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
