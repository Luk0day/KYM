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

/// Existe para desenvolver e testar o login sem o Supabase configurado.
class FakeAuthDataSource implements AuthDataSource {
  FakeAuthDataSource({
    List<FakeAuthAccount>? accounts,
    this.latency = const Duration(milliseconds: 600),
  }) : _accounts = accounts ?? defaultAccounts;

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

  final Duration latency;

  /// Quando definido, a próxima operação falha com este tipo e o valor é
  /// limpo em seguida. Útil para simular rede fora do ar, perfil ausente etc.
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

    return _currentUser = _toModel(account);
  }

  @override
  Future<AuthUserModel?> getCurrentUser() async {
    await _simulateLatency();
    _throwIfFailureScheduled();
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    await _simulateLatency();
    _currentUser = null;
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
