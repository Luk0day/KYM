import '../repositories/auth_repository.dart';

class UpdatePassword {
  UpdatePassword(this._repository);

  final AuthRepository _repository;

  /// Define a nova senha e encerra a sessão de recuperação, para o usuário
  /// entrar de novo com a senha nova. Uma falha ao sair não desfaz a troca.
  Future<void> call({required String password}) async {
    await _repository.updatePassword(password: password);
    try {
      await _repository.signOut();
    } on Object {
      return;
    }
  }
}
