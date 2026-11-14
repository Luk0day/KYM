import '../entities/authenticated_user.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUser {
  GetCurrentUser(this._repository);

  final AuthRepository _repository;

  Future<AuthenticatedUser?> call() {
    return _repository.getCurrentUser();
  }
}
