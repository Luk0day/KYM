import 'dart:async';

import 'package:kym/modules/auth/domain/entities/authenticated_user.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/auth/domain/usecases/get_current_user.dart';
import 'package:kym/modules/auth/domain/usecases/sign_out.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';
import 'package:kym/modules/auth/infra/repositories/auth_repository_impl.dart';
import 'package:kym/modules/auth/presenter/controllers/session_controller.dart';
import 'package:kym/modules/stores/domain/entities/store_summary.dart';
import 'package:kym/modules/stores/domain/repositories/store_list_repository.dart';

/// Repositório em memória: emite a lista atual ao assinar e de novo a cada
/// [emit], como o banco local faria.
class FakeStoreListRepository implements StoreListRepository {
  FakeStoreListRepository([List<StoreSummary> stores = const []])
    : _stores = stores;

  List<StoreSummary> _stores;
  final _changes = StreamController<List<StoreSummary>>.broadcast();

  @override
  Stream<List<StoreSummary>> watchStores() async* {
    yield _stores;
    yield* _changes.stream;
  }

  void emit(List<StoreSummary> stores) {
    _stores = stores;
    _changes.add(stores);
  }

  Future<void> close() => _changes.close();
}

SessionController sessionFor(UserRole role) {
  final repository = AuthRepositoryImpl(
    FakeAuthDataSource(latency: Duration.zero),
  );
  return SessionController(
    GetCurrentUser(repository),
    SignOut(repository),
  )..start(AuthenticatedUser(id: 'user-1', email: 'user@kym.test', role: role));
}

/// Três lojas, uma delas inativa.
const sampleStores = [
  StoreSummary(
    id: 's1',
    name: 'Pão de Açúcar Boa Viagem',
    code: 'L001',
    address: 'Av. Boa Viagem, 3500',
    city: 'Recife',
    openOrders: 2,
    preventiveOrders: 1,
    correctiveOrders: 1,
  ),
  StoreSummary(
    id: 's2',
    name: 'Carrefour Água Fria',
    code: 'L002',
    address: 'Rua da Matriz, 10',
    city: 'Olinda',
  ),
  StoreSummary(
    id: 's3',
    name: 'Atacadão Jaboatão',
    code: 'L003',
    city: 'Recife',
    isActive: false,
    openOrders: 1,
    overdueOrders: 1,
    preventiveOrders: 1,
  ),
];
