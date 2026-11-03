import '../../domain/entities/authenticated_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/errors/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import '../models/auth_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource);

  final AuthDataSource _dataSource;

  @override
  Future<AuthenticatedUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final model = await _dataSource.signInWithEmail(
      email: email,
      password: password,
    );

    return _toEntity(model);
  }

  @override
  Future<AuthenticatedUser> signInWithGoogle() async {
    final model = await _dataSource.signInWithGoogle();

    return _toEntity(model);
  }

  @override
  Future<AuthenticatedUser?> getCurrentUser() async {
    final model = await _dataSource.getCurrentUser();

    if (model == null) {
      return null;
    }

    return _toEntity(model);
  }

  @override
  Future<void> signOut() {
    return _dataSource.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _dataSource.sendPasswordResetEmail(email: email);
  }

  AuthenticatedUser _toEntity(AuthUserModel model) {
    final id = model.id.trim();
    final email = model.email.trim();

    if (id.isEmpty || email.isEmpty) {
      throw const AuthFailure(AuthFailureType.invalidProfile);
    }

    return AuthenticatedUser(
      id: id,
      email: email,
      displayName: model.displayName,
      role: _parseRole(model.role),
    );
  }

  UserRole _parseRole(String value) {
    switch (value.trim().toLowerCase()) {
      case 'tecnico':
        return UserRole.tecnico;

      case 'gestor':
        return UserRole.gestor;

      case 'lojista':
        return UserRole.lojista;

      default:
        throw const AuthFailure(AuthFailureType.invalidProfile);
    }
  }
}
