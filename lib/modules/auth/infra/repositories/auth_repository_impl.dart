import '../../../../app/storage/key_value_store.dart';
import '../../../../app/storage/storage_keys.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/entities/password_recovery_event.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/errors/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import '../models/auth_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  /// [recoveryStore] guarda a marca de recuperação em andamento; precisa
  /// sobreviver ao fechamento do app, como a sessão.
  AuthRepositoryImpl(this._dataSource, {KeyValueStore? recoveryStore})
    : _recoveryStore = recoveryStore ?? InMemoryKeyValueStore();

  final AuthDataSource _dataSource;
  final KeyValueStore _recoveryStore;

  /// Sessão de recuperação aberta nesta execução do app.
  bool _recoveringNow = false;

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

  /// A sessão aberta pelo link de redefinição não dá acesso ao app. Se o app
  /// foi fechado na tela de nova senha, a marca ainda existe na abertura
  /// seguinte: a sessão é encerrada e o usuário volta ao login.
  @override
  Future<AuthenticatedUser?> getCurrentUser() async {
    if (_recoveringNow) {
      return null;
    }
    if (await _readRecoveryMark() != null) {
      if (!_recoveringNow) {
        await _endLeftoverRecovery();
      }
      return null;
    }

    final model = await _dataSource.getCurrentUser();

    if (model == null) {
      return null;
    }

    return _toEntity(model);
  }

  /// A marca só sai depois de a sessão ser encerrada; se a saída falhar, a
  /// próxima abertura tenta de novo.
  @override
  Future<void> signOut() async {
    await _dataSource.signOut();
    _recoveringNow = false;
    await _clearRecoveryMark();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    return _dataSource.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> updatePassword({required String password}) {
    return _dataSource.updatePassword(password: password);
  }

  @override
  Stream<PasswordRecoveryEvent> get passwordRecoveryEvents =>
      _dataSource.passwordRecoveryEvents.asyncMap((event) async {
        if (event == PasswordRecoveryEvent.started) {
          _recoveringNow = true;
          await _writeRecoveryMark();
        }
        return event;
      });

  Future<void> _endLeftoverRecovery() async {
    try {
      await signOut();
    } on Object {
      return;
    }
  }

  Future<String?> _readRecoveryMark() async {
    try {
      return await _recoveryStore.read(StorageKeys.passwordRecoveryPending);
    } on Object {
      return null;
    }
  }

  Future<void> _writeRecoveryMark() async {
    try {
      await _recoveryStore.write(StorageKeys.passwordRecoveryPending, '1');
    } on Object {
      return;
    }
  }

  Future<void> _clearRecoveryMark() async {
    try {
      await _recoveryStore.delete(StorageKeys.passwordRecoveryPending);
    } on Object {
      return;
    }
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
