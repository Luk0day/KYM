import 'package:flutter_modular/flutter_modular.dart';

import '../modules/auth/auth_module.dart';
import '../modules/auth/infra/datasources/auth_datasource.dart';
import '../modules/home/home_module.dart';
import '../modules/home/home_routes.dart';

/// A fábrica do datasource é injetada para que testes e o modo fake troquem o
/// Supabase sem alterar os módulos.
class AppModule extends Module {
  AppModule({required this.authDataSourceFactory});

  final AuthDataSource Function() authDataSourceFactory;

  @override
  void register(ModularContext c) {
    c
      ..module(
        AuthModule(
          dataSourceFactory: authDataSourceFactory,
          authenticatedRoute: HomeRoutes.root,
        ),
      )
      ..module(HomeModule());
  }
}
