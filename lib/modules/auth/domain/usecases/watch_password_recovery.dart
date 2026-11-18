import '../entities/password_recovery_event.dart';
import '../repositories/auth_repository.dart';

class WatchPasswordRecovery {
  WatchPasswordRecovery(this._repository);

  final AuthRepository _repository;

  Stream<PasswordRecoveryEvent> call() => _repository.passwordRecoveryEvents;
}
