import '../models/auth_user_model.dart';

abstract interface class AuthDataSource {
  /// Autentica um usuário existente com e-mail e senha.
  Future<AuthUserModel> signInWithEmail({
    required String email,
    required String password,
  });

  /// Obtém os dados do usuário da sessão atual.
  ///
  /// Retorna null quando não existe uma sessão autenticada.
  /// Deve sinalizar uma falha se houver sessão, mas os dados
  /// obrigatórios do perfil não puderem ser obtidos ou validados.
  Future<AuthUserModel?> getCurrentUser();

  /// Encerra a sessão atual na fonte de dados.
  Future<void> signOut();
}
