import '../../../../app/storage/key_value_store.dart';
import '../../../../app/storage/storage_keys.dart';
import '../../domain/errors/auth_failure.dart';
import '../models/auth_user_model.dart';
import 'auth_datasource.dart';

class FakeAuthAccount {
  const FakeAuthAccount({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
    this.displayName,
  });

  final String id;
  final String email;
  final String password;
  final String role;
  final String? displayName;
}

class FakeAuthDataSource implements AuthDataSource {
  FakeAuthDataSource({
    List<FakeAuthAccount>? accounts,
    this.latency = const Duration(milliseconds: 600),
    KeyValueStore? sessionStore,
  }) : _accounts = accounts ?? defaultAccounts,
       _sessionStore = sessionStore ?? InMemoryKeyValueStore();

  static const List<FakeAuthAccount> defaultAccounts = [
    FakeAuthAccount(
      id: 'fake-tecnico-id',
      email: 'tecnico@kym.test',
      password: 'kym12345',
      role: 'tecnico',
      displayName: 'Técnico Teste',
    ),
    FakeAuthAccount(
      id: 'fake-gestor-id',
      email: 'gestor@kym.test',
      password: 'kym12345',
      role: 'gestor',
      displayName: 'Gestor Teste',
    ),
    FakeAuthAccount(
      id: 'fake-lojista-id',
      email: 'lojista@kym.test',
      password: 'kym12345',
      role: 'lojista',
      displayName: 'Lojista Teste',
    ),
  ];

  final List<FakeAuthAccount> _accounts;
  final KeyValueStore _sessionStore;
  final Duration latency;

  final List<String> passwordResetRequests = [];

  AuthFailureType? nextFailure;

  AuthUserModel? _currentUser;

  @override
  Future<AuthUserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _simulateLatency();
    _throwIfFailureScheduled();

    final normalizedEmail = email.trim().toLowerCase();
    final account = _accounts
        .where((item) => item.email.toLowerCase() == normalizedEmail)
        .firstOrNull;

    if (account == null || account.password != password) {
      throw const AuthFailure(AuthFailureType.invalidCredentials);
    }

    await _sessionStore.write(StorageKeys.fakeSessionUserId, account.id);
    return _currentUser = _toModel(account);
  }

  @override
  Future<AuthUserModel?> getCurrentUser() async {
    await _simulateLatency();
    _throwIfFailureScheduled();

    if (_currentUser != null) {
      return _currentUser;
    }

    final savedId = await _sessionStore.read(StorageKeys.fakeSessionUserId);
    final account = _accounts.where((item) => item.id == savedId).firstOrNull;
    return _currentUser = account == null ? null : _toModel(account);
  }

  @override
  Future<void> signOut() async {
    await _simulateLatency();
    _currentUser = null;
    await _sessionStore.delete(StorageKeys.fakeSessionUserId);
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _simulateLatency();
    _throwIfFailureScheduled();
    passwordResetRequests.add(email.trim());
  }

  AuthUserModel _toModel(FakeAuthAccount account) {
    return AuthUserModel(
      id: account.id,
      email: account.email,
      displayName: account.displayName,
      role: account.role,
    );
  }

  Future<void> _simulateLatency() {
    if (latency == Duration.zero) {
      return Future<void>.value();
    }
    return Future<void>.delayed(latency);
  }

  void _throwIfFailureScheduled() {
    final type = nextFailure;
    if (type == null) {
      return;
    }
    nextFailure = null;
    throw AuthFailure(type);
  }
}
