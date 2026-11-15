import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/app_module.dart';
import 'app/config/env.dart';
import 'app/database/app_database.dart';
import 'app/database/seed/fake_data_seeder.dart';
import 'app/di/auth_data_source_factory.dart';
import 'app/di/session_storage_factory.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  if (!Env.useFakeAuth) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: createSessionStorage(Env.supabaseUrl),
      ),
    );
  }

  final database = AppDatabase();
  if (Env.useFakeAuth) {
    // Sem Supabase: o app roda só com o seed local, sem sincronização.
    await FakeDataSeeder(database).seedIfEmpty();
  }

  runApp(
    ModularApp(
      module: AppModule(
        authDataSourceFactory: createAuthDataSource,
        databaseFactory: () => database,
      ),
      child: const KymApp(),
    ),
  );
}
