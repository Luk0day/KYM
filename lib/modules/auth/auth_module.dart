import 'package:flutter_modular/flutter_modular.dart';

import '../../app/storage/key_value_store.dart';
import 'auth_routes.dart';
import 'domain/errors/auth_failure.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/get_current_user.dart';
import 'domain/usecases/send_password_reset_email.dart';
import 'domain/usecases/sign_in_with_email.dart';
import 'domain/usecases/sign_in_with_google.dart';
import 'domain/usecases/sign_out.dart';
import 'domain/usecases/update_password.dart';
import 'domain/usecases/watch_password_recovery.dart';
import 'infra/datasources/auth_datasource.dart';
import 'infra/repositories/auth_repository_impl.dart';
import 'presenter/controllers/forgot_password_controller.dart';
import 'presenter/controllers/login_controller.dart';
import 'presenter/controllers/password_recovery_controller.dart';
import 'presenter/controllers/reset_password_controller.dart';
import 'presenter/controllers/session_controller.dart';
import 'presenter/pages/forgot_password_page.dart';
import 'presenter/pages/login_page.dart';
import 'presenter/pages/reset_password_page.dart';
import 'presenter/pages/splash_page.dart';
import 'presenter/utils/password_update_failure_message.dart';

/// Sem `path`: as dependências são compartilhadas (vivem o app todo) e as
/// rotas ficam na raiz.
///
/// [dataSourceFactory] e [authenticatedRoute] vêm por parâmetro para o módulo
/// não conhecer o Supabase, o fake nem o módulo Home.
class AuthModule extends Module {
  AuthModule({
    required this.dataSourceFactory,
    required this.authenticatedRoute,
    this.recoveryStoreFactory,
  });

  final AuthDataSource Function() dataSourceFactory;
  final String authenticatedRoute;

  /// Onde fica a marca de recuperação de senha em andamento. Sem ela, a marca
  /// vive só na memória (testes).
  final KeyValueStore Function()? recoveryStoreFactory;

  @override
  void register(ModularContext c) {
    c
      ..addLazySingleton<AuthDataSource>(dataSourceFactory)
      ..addLazySingleton<AuthRepository>(
        (AuthDataSource dataSource) => AuthRepositoryImpl(
          dataSource,
          recoveryStore: recoveryStoreFactory?.call(),
        ),
      )
      ..addLazySingleton<SignInWithEmail>(SignInWithEmail.new)
      ..addLazySingleton<SignInWithGoogle>(SignInWithGoogle.new)
      ..addLazySingleton<GetCurrentUser>(GetCurrentUser.new)
      ..addLazySingleton<SignOut>(SignOut.new)
      ..addLazySingleton<SendPasswordResetEmail>(SendPasswordResetEmail.new)
      ..addLazySingleton<UpdatePassword>(UpdatePassword.new)
      ..addLazySingleton<WatchPasswordRecovery>(WatchPasswordRecovery.new)
      ..addLazySingleton<SessionController>(SessionController.new)
      ..addLazySingleton<PasswordRecoveryController>(
        PasswordRecoveryController.new,
      )
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
        child: (context, state) => ForgotPasswordPage(
          onBackToLogin: () => context.navigate(AuthRoutes.login),
          notice: state.query[AuthRoutes.noticeParam] ==
                  AuthRoutes.linkInvalidNotice
              ? AuthFailureType.recoveryLinkInvalid.passwordUpdateMessage
              : null,
        ),
      )
      ..route(
        AuthRoutes.resetPassword,
        provide: (scoped) {
          scoped.addChangeNotifier<ResetPasswordController>(
            ResetPasswordController.new,
          );
        },
        child: (context, _) => ResetPasswordPage(
          onCancel: () => context.navigate(AuthRoutes.login),
          onGoToLogin: () => context.navigate(AuthRoutes.login),
          onRequestNewLink: () => context.navigate(AuthRoutes.forgotPassword),
        ),
      );
  }
}
