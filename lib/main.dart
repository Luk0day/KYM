import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/app_module.dart';
import 'app/config/env.dart';
import 'app/di/auth_data_source_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Com USE_FAKE_AUTH=true o Supabase nem precisa estar configurado.
  if (!Env.useFakeAuth) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }

  runApp(
    ModularApp(
      module: AppModule(authDataSourceFactory: createAuthDataSource),
      child: const KymApp(),
    ),
  );
}
