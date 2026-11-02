import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/storage/key_value_store.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/auth/domain/usecases/get_current_user.dart';
import 'package:kym/modules/auth/domain/usecases/sign_out.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/infra/repositories/auth_repository_impl.dart';
import 'package:kym/modules/auth/presenter/controllers/session_controller.dart';

FakeAuthDataSource _newDataSource(KeyValueStore store) {
  return FakeAuthDataSource(latency: Duration.zero, sessionStore: store);
}

SessionController _newSession(FakeAuthDataSource dataSource) {
  final repository = AuthRepositoryImpl(dataSource);
  return SessionController(GetCurrentUser(repository), SignOut(repository));
}

void main() {
  late InMemoryKeyValueStore store;

  setUp(() => store = InMemoryKeyValueStore());

  test('restaura a sessão ao "reabrir o app"', () async {
    await _newDataSource(store).signInWithEmail(
      email: 'gestor@kym.test',
      password: 'kym12345',
    );

    final session = _newSession(_newDataSource(store));
    await session.restore();

    expect(session.isAuthenticated, isTrue);
    expect(session.user?.role, UserRole.gestor);
  });

  test('sem login prévio, não restaura nada', () async {
    final session = _newSession(_newDataSource(store));
    await session.restore();

    expect(session.isAuthenticated, isFalse);
  });

  test('logout limpa a sessão persistida', () async {
    final dataSource = _newDataSource(store);
    final session = _newSession(dataSource);

    await dataSource.signInWithEmail(
      email: 'tecnico@kym.test',
      password: 'kym12345',
    );
    await session.restore();
    expect(session.isAuthenticated, isTrue);

    await session.signOut();
    expect(session.isAuthenticated, isFalse);

    final reopened = _newSession(_newDataSource(store));
    await reopened.restore();
    expect(reopened.isAuthenticated, isFalse);
  });
}
