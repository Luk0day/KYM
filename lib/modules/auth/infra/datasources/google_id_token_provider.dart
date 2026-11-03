/// Obtém o ID token do Google. Isola o pacote `google_sign_in` do datasource do
/// Supabase, o que permite trocar a implementação em testes.
abstract interface class GoogleIdTokenProvider {
  /// Abre a seleção de conta e devolve o ID token.
  /// Lança `AuthFailure(AuthFailureType.cancelled)` se o usuário desistir.
  Future<String> fetchIdToken();

  /// Encerra a conta Google no aparelho, para a próxima entrada voltar a
  /// perguntar qual conta usar.
  Future<void> signOut();
}
