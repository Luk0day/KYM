import '../entities/authenticated_user.dart';
import '../entities/password_recovery_event.dart';

abstract interface class AuthRepository {
  /// Retorna o usuário autenticado com um perfil válido no KYM.
  /// Não realiza cadastro de novos usuários.
  Future<AuthenticatedUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Entra com a conta Google escolhida pelo usuário (Google Sign-In + Supabase
  /// Auth). Retorna o usuário com perfil válido no KYM.
  /// Lança [AuthFailure] com `cancelled` se o usuário desistir da escolha.
  Future<AuthenticatedUser> signInWithGoogle();

  /// Retorna null quando não existe uma sessão autenticada.
  /// Se existir uma sessão, mas não for possível validar o perfil,
  /// a implementação deverá comunicar a falha correspondente.
  Future<AuthenticatedUser?> getCurrentUser();

  Future<void> signOut();

  Future<void> sendPasswordResetEmail({required String email});

  /// Troca a senha de quem está na sessão de recuperação aberta pelo link do
  /// e-mail. Lança [AuthFailure] com weakPassword, samePassword ou
  /// recoveryLinkInvalid (sessão expirada ou ausente).
  Future<void> updatePassword({required String password});

  /// Emite started quando o link do e-mail abre a sessão de recuperação e
  /// linkInvalid quando o link chega expirado ou já usado.
  Stream<PasswordRecoveryEvent> get passwordRecoveryEvents;
}
