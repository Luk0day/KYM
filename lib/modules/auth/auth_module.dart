import 'package:flutter_modular/flutter_modular.dart';

import 'auth_routes.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/get_current_user.dart';
import 'domain/usecases/send_password_reset_email.dart';
import 'domain/usecases/sign_in_with_email.dart';
import 'domain/usecases/sign_out.dart';
import 'infra/datasources/auth_datasource.dart';
import 'infra/repositories/auth_repository_impl.dart';
import 'presenter/controllers/forgot_password_controller.dart';
import 'presenter/controllers/login_controller.dart';
import 'presenter/controllers/session_controller.dart';
import 'presenter/pages/forgot_password_page.dart';
import 'presenter/pages/login_page.dart';
import 'presenter/pages/splash_page.dart';

/// Sem `path`: as dependências são compartilhadas (vivem o app todo) e as
/// rotas ficam na raiz.
///
/// [dataSourceFactory] e [authenticatedRoute] vêm por parâmetro para o módulo
/// não conhecer o Supabase, o fake nem o módulo Home.
class AuthModule extends Module {
  AuthModule({
    required this.dataSourceFactory,
    required this.authenticatedRoute,
  });

  final AuthDataSource Function() dataSourceFactory;
  final String authenticatedRoute;

  @override
  void register(ModularContext c) {
    c
      ..addLazySingleton<AuthDataSource>(dataSourceFactory)
      ..addLazySingleton<AuthRepository>(AuthRepositoryImpl.new)
      ..addLazySingleton<SignInWithEmail>(SignInWithEmail.new)
      ..addLazySingleton<GetCurrentUser>(GetCurrentUser.new)
      ..addLazySingleton<SignOut>(SignOut.new)
      ..addLazySingleton<SendPasswordResetEmail>(SendPasswordResetEmail.new)
      ..addLazySingleton<SessionController>(SessionController.new)
      ..route(
        AuthRoutes.splash,
        child: (context, _) => SplashPage(
          session: inject<SessionController>(),
          onResolved: (authenticated) {
            context.navigate(
              authenticated ? authenticatedRoute : AuthRoutes.login,
            );
          },
        ),
      )
      ..route(
        AuthRoutes.login,
        // O controller vive só enquanto a tela de login estiver aberta.
        provide: (scoped) {
          scoped.addChangeNotifier<LoginController>(LoginController.new);
        },
        child: (context, _) => LoginPage(
          onAuthenticated: (user) {
            inject<SessionController>().start(user);
            context.navigate(authenticatedRoute);
          },
          onForgotPassword: () => context.navigate(AuthRoutes.forgotPassword),
        ),
      )
      ..route(
        AuthRoutes.forgotPassword,
        provide: (scoped) {
          scoped.addChangeNotifier<ForgotPasswordController>(
            ForgotPasswordController.new,
          );
        },
        child: (context, _) => ForgotPasswordPage(
          onBackToLogin: () => context.navigate(AuthRoutes.login),
        ),
      );
  }
}
