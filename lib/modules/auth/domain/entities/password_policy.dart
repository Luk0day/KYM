/// Regra da nova senha, usada pela validação da tela, pelas mensagens e pelo
/// modo fake. O Supabase pode exigir mais, conforme a configuração do projeto.
abstract final class PasswordPolicy {
  static const int minLength = 6;
}
