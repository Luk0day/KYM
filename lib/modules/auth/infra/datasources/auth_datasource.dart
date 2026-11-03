import '../models/auth_user_model.dart';

abstract interface class AuthDataSource {
  Future<AuthUserModel> signInWithEmail({
    required String email,
    required String password,
  });

  /// Retorna null quando não existe uma sessão autenticada.
  /// Deve sinalizar uma falha se houver sessão, mas os dados
  /// obrigatórios do perfil não puderem ser obtidos ou validados.
  Future<AuthUserModel?> getCurrentUser();

  Future<void> signOut();

  Future<void> sendPasswordResetEmail({required String email});
}
