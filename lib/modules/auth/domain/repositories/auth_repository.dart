import '../entities/authenticated_user.dart';

abstract interface class AuthRepository {
  /// Retorna o usuário autenticado com um perfil válido no KYM.
  /// Não realiza cadastro de novos usuários.
  Future<AuthenticatedUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Retorna null quando não existe uma sessão autenticada.
  /// Se existir uma sessão, mas não for possível validar o perfil,
  /// a implementação deverá comunicar a falha correspondente.
  Future<AuthenticatedUser?> getCurrentUser();

  Future<void> signOut();
}
