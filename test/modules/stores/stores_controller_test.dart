import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/stores/domain/entities/store_summary.dart';
import 'package:kym/modules/stores/domain/repositories/store_list_repository.dart';
import 'package:kym/modules/stores/domain/services/sync_service.dart';
import 'package:kym/modules/stores/domain/usecases/refresh_stores.dart';
import 'package:kym/modules/stores/domain/usecases/watch_stores.dart';
import 'package:kym/modules/stores/presenter/controllers/stores_controller.dart';
import 'package:kym/modules/stores/presenter/utils/stores_messages.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/store_fakes.dart';

class MockSyncService extends Mock implements SyncService {}

class MockStoreListRepository extends Mock implements StoreListRepository {}

void main() {
  late FakeStoreListRepository repository;
  late MockSyncService syncService;

  StoresController build({UserRole role = UserRole.tecnico}) {
    return StoresController(
      WatchStores(repository),
      RefreshStores(syncService),
      sessionFor(role),
    );
  }

  Future<void> waitDebounce() async {
    await Future<void>.delayed(
      StoresController.searchDebounce + const Duration(milliseconds: 50),
    );
    await pumpEventQueue();
  }

  List<String> ids(StoresController controller) =>
      controller.result.items.map((s) => s.id).toList();

  setUp(() {
    repository = FakeStoreListRepository(sampleStores);
    syncService = MockSyncService();
    when(syncService.sync).thenAnswer((_) async {});
  });

  tearDown(() => repository.close());

  test('começa carregando e fica pronto com as lojas', () async {
    final controller = build()..load();
    addTearDown(controller.dispose);

    expect(controller.status, StoresStatus.loading);

    await pumpEventQueue();

    expect(controller.status, StoresStatus.ready);
    expect(ids(controller), ['s2', 's1']);
  });

  test('load chamado de novo não assina duas vezes', () async {
    final controller = build()
      ..load()
      ..load();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await pumpEventQueue();

    expect(notifications, 1);
  });

  test('gestor vê lojas inativas, técnico não', () async {
    final gestor = build(role: UserRole.gestor)..load();
    final tecnico = build()..load();
    addTearDown(gestor.dispose);
    addTearDown(tecnico.dispose);

    await pumpEventQueue();

    expect(ids(gestor), ['s3', 's2', 's1']);
    expect(ids(tecnico), ['s2', 's1']);
  });

  test('lojista também não vê inativas', () async {
    final controller = build(role: UserRole.lojista)..load();
    addTearDown(controller.dispose);

    await pumpEventQueue();

    expect(ids(controller), ['s2', 's1']);
  });

  group('busca e filtros', () {
    test('a busca espera o debounce e só usa o último termo', () async {
      final controller = build()..load();
      addTearDown(controller.dispose);
      await pumpEventQueue();

      controller
        ..setQuery('o')
        ..setQuery('olinda');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(ids(controller), ['s2', 's1']);

      await waitDebounce();

      expect(ids(controller), ['s2']);
      expect(controller.filter.query, 'olinda');
    });

    test('filtra por cidade e só pendências, e limpa tudo', () async {
      final controller = build()..load();
      addTearDown(controller.dispose);
      await pumpEventQueue();

      controller.applyFilters(city: 'Recife', onlyWithPending: true);
      await pumpEventQueue();
      expect(ids(controller), ['s1']);

      controller.applyFilters(onlyWithPending: false);
      await pumpEventQueue();
      expect(controller.filter.city, isNull);
      expect(ids(controller), ['s2', 's1']);

      controller
        ..setQuery('xyz')
        ..clearAll();
      await waitDebounce();
      expect(controller.filter.isEmpty, isTrue);
      expect(ids(controller), ['s2', 's1']);
    });

    test('novos dados do banco chegam sem recarregar', () async {
      final controller = build()..load();
      addTearDown(controller.dispose);
      await pumpEventQueue();

      repository.emit(const [StoreSummary(id: 'n', name: 'Nova')]);
      await pumpEventQueue();

      expect(ids(controller), ['n']);
    });
  });

  group('erro de leitura', () {
    test('mostra erro e se recupera ao tentar de novo', () async {
      final mock = MockStoreListRepository();
      when(mock.watchStores).thenAnswer(
        (_) => Stream<List<StoreSummary>>.error(StateError('banco fechado')),
      );
      final controller = StoresController(
        WatchStores(mock),
        RefreshStores(syncService),
        sessionFor(UserRole.tecnico),
      )..load();
      addTearDown(controller.dispose);

      await pumpEventQueue();
      expect(controller.status, StoresStatus.error);

      when(mock.watchStores).thenAnswer(
        (_) => Stream.value(sampleStores),
      );
      controller.retry();
      expect(controller.status, StoresStatus.loading);
      await pumpEventQueue();

      expect(controller.status, StoresStatus.ready);
    });
  });

  group('sincronização', () {
    test('sucesso devolve true e não deixa mensagem', () async {
      final controller = build();
      addTearDown(controller.dispose);

      expect(await controller.refresh(), isTrue);
      expect(controller.syncMessage, isNull);
      verify(syncService.sync).called(1);
    });

    for (final entry in {
      SyncFailureType.offline: SyncFailureType.offline.userMessage,
      SyncFailureType.server: SyncFailureType.server.userMessage,
      SyncFailureType.unexpected: SyncFailureType.unexpected.userMessage,
    }.entries) {
      test('falha ${entry.key.name} devolve false com a mensagem', () async {
        when(syncService.sync).thenThrow(SyncFailure(entry.key));
        final controller = build();
        addTearDown(controller.dispose);

        expect(await controller.refresh(), isFalse);
        expect(controller.syncMessage, entry.value);
      });
    }

    test('erro desconhecido vira mensagem genérica', () async {
      when(syncService.sync).thenThrow(StateError('boom'));
      final controller = build();
      addTearDown(controller.dispose);

      expect(await controller.refresh(), isFalse);
      expect(
        controller.syncMessage,
        SyncFailureType.unexpected.userMessage,
      );
    });

    test('a mensagem some na próxima tentativa bem-sucedida', () async {
      when(syncService.sync).thenThrow(const SyncFailure(SyncFailureType.offline));
      final controller = build();
      addTearDown(controller.dispose);
      await controller.refresh();

      when(syncService.sync).thenAnswer((_) async {});
      await controller.refresh();

      expect(controller.syncMessage, isNull);
    });

    test('a mensagem de erro de leitura é clara', () {
      expect(storesLoadErrorMessage, contains('lojas'));
    });
  });

  test('dispose durante o debounce não lança', () async {
    final controller = build()..load();
    await pumpEventQueue();

    controller
      ..setQuery('abc')
      ..dispose();

    await waitDebounce();
  });
}
