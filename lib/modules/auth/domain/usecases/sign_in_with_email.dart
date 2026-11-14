import '../entities/authenticated_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithEmail {
  SignInWithEmail(this._repository);

  final AuthRepository _repository;

  Future<AuthenticatedUser> call({
    required String email,
    required String password,
  }) {
    return _repository.signInWithEmail(email: email.trim(), password: password);
  }
}
