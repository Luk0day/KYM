import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'KYM',
      home: ConnectionCheckPage(),
    );
  }
}

// Tela temporária só para validar o critério da B03 (app conecta).
// Remover quando a tela de login entrar.
class ConnectionCheckPage extends StatelessWidget {
  const ConnectionCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FutureBuilder(
          future: Supabase.instance.client.from('stores').select().limit(1),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text('Erro: ${snapshot.error}');
            if (!snapshot.hasData) return const CircularProgressIndicator();
            return const Text('Conectado ao Supabase ✅');
          },
        ),
      ),
    );
  }
}
