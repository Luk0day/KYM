import '../entities/authenticated_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogle {
  SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  Future<AuthenticatedUser> call() => _repository.signInWithGoogle();
}
