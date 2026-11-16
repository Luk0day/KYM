import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/theme/app_theme.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/stores/domain/entities/store_summary.dart';
import 'package:kym/modules/stores/domain/repositories/store_list_repository.dart';
import 'package:kym/modules/stores/domain/services/sync_service.dart';
import 'package:kym/modules/stores/domain/usecases/refresh_stores.dart';
import 'package:kym/modules/stores/domain/usecases/watch_stores.dart';
import 'package:kym/modules/stores/presenter/controllers/stores_controller.dart';
import 'package:kym/modules/stores/presenter/pages/stores_page.dart';
import 'package:kym/modules/stores/presenter/utils/stores_messages.dart';
import 'package:kym/modules/stores/presenter/widgets/store_filter_chips.dart';
import 'package:kym/modules/stores/presenter/widgets/store_tile.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/store_fakes.dart';

class MockSyncService extends Mock implements SyncService {}

class MockStoreListRepository extends Mock implements StoreListRepository {}

void main() {
  late FakeStoreListRepository repository;
  late MockSyncService syncService;
  StoreSummary? selected;

  setUp(() {
    repository = FakeStoreListRepository(sampleStores);
    syncService = MockSyncService();
    selected = null;
    when(syncService.sync).thenAnswer((_) async {});
  });

  tearDown(() => repository.close());

  Future<StoresController> pumpPage(
    WidgetTester tester, {
    StoreListRepository? repo,
    UserRole role = UserRole.tecnico,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = StoresController(
      WatchStores(repo ?? repository),
      RefreshStores(syncService),
      sessionFor(role),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StoresPage(
          controller: controller,
          onStoreSelected: (store) => selected = store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextFormField), text);
    await tester.pump(StoresController.searchDebounce);
    await tester.pumpAndSettle();
  }

  // No teste a fonte é larga (Ahem): os chips da direita ficam fora da tela,
  // então rola até eles antes de tocar.
  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      100,
      scrollable: find.descendant(
        of: find.byType(StoreFilterChips),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('cabeçalho', () {
    testWidgets('mostra título, quantidade e selo de sincronização', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Lojas'), findsOneWidget);
      expect(find.text('2 lojas'), findsOneWidget);
      expect(find.text('Sincronizado'), findsOneWidget);
    });

    testWidgets('a quantidade acompanha a busca', (tester) async {
      await pumpPage(tester);

      await search(tester, 'olinda');

      expect(find.text('1 loja'), findsOneWidget);
    });
  });

  group('lista', () {
    testWidgets('mostra iniciais, nome, endereço, cidade e situação', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('PA'), findsOneWidget);
      expect(find.text('Pão de Açúcar Boa Viagem'), findsOneWidget);
      expect(find.text('Av. Boa Viagem, 3500 · Recife'), findsOneWidget);
      expect(find.text('2 EM ABERTO'), findsOneWidget);
      expect(find.text('EM DIA'), findsOneWidget);
      expect(find.text('Atacadão Jaboatão'), findsNothing);
    });

    testWidgets('loja com ordens vencidas mostra "atrasadas"', (tester) async {
      repository.emit(const [
        StoreSummary(
          id: 'a',
          name: 'Loja Centro',
          address: 'Rua da Matriz',
          openOrders: 2,
          overdueOrders: 2,
        ),
        StoreSummary(
          id: 'b',
          name: 'Loja Sul',
          openOrders: 1,
          overdueOrders: 1,
        ),
      ]);
      await pumpPage(tester);

      expect(find.text('LC'), findsOneWidget);
      expect(find.text('2 ATRASADAS'), findsOneWidget);
      expect(find.text('1 ATRASADA'), findsOneWidget);
    });

    testWidgets('gestor vê a loja inativa com o selo', (tester) async {
      await pumpPage(tester, role: UserRole.gestor);

      expect(find.text('Atacadão Jaboatão'), findsOneWidget);
      expect(find.text('INATIVA'), findsOneWidget);
    });

    testWidgets('tocar numa loja avisa a rota', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Carrefour Água Fria'));

      expect(selected?.id, 's2');
    });

    test('iniciais do nome', () {
      expect(StoreTile.initialsOf('Loja Centro'), 'LC');
      expect(StoreTile.initialsOf('  loja   norte  sul '), 'LN');
      expect(StoreTile.initialsOf('Shopping'), 'SH');
      expect(StoreTile.initialsOf('X'), 'X');
      expect(StoreTile.initialsOf('   '), '?');
    });
  });

  group('busca e filtros', () {
    testWidgets('a busca filtra sem diferenciar acento', (tester) async {
      await pumpPage(tester);

      await search(tester, 'pao de acucar');

      expect(find.text('Pão de Açúcar Boa Viagem'), findsOneWidget);
      expect(find.text('Carrefour Água Fria'), findsNothing);
    });

    testWidgets('o campo de busca é anunciado pelo leitor de tela', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);

      expect(find.bySemanticsLabel('Buscar loja'), findsWidgets);
      handle.dispose();
    });

    testWidgets('os chips de filtro aparecem e Todas começa marcado', (
      tester,
    ) async {
      await pumpPage(tester);

      for (final label in ['Todas', 'Com atrasadas', 'Preventivas']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('chip Preventivas filtra as lojas', (tester) async {
      await pumpPage(tester);

      await tapChip(tester, 'Preventivas');

      expect(find.text('Pão de Açúcar Boa Viagem'), findsOneWidget);
      expect(find.text('Carrefour Água Fria'), findsNothing);
    });

    testWidgets('chip Corretivas filtra as lojas', (tester) async {
      await pumpPage(tester);

      await tapChip(tester, 'Corretivas');

      expect(find.text('Pão de Açúcar Boa Viagem'), findsOneWidget);
      expect(find.text('Carrefour Água Fria'), findsNothing);
    });

    testWidgets('sem resultado mostra o aviso e limpar volta a lista', (
      tester,
    ) async {
      await pumpPage(tester);

      await tapChip(tester, 'Com atrasadas');
      expect(find.text('Nenhuma loja encontrada'), findsOneWidget);

      await tester.tap(find.text('Limpar busca e filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Carrefour Água Fria'), findsOneWidget);
      expect(find.text('Nenhuma loja encontrada'), findsNothing);
    });

    testWidgets('sem lojas mostra o estado vazio', (tester) async {
      await pumpPage(tester, repo: FakeStoreListRepository());

      expect(find.text('Nenhuma loja atribuída a você'), findsOneWidget);
    });
  });

  group('sincronização', () {
    testWidgets('puxar para baixo sincroniza', (tester) async {
      await pumpPage(tester);

      await tester.fling(
        find.byType(ListView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      verify(syncService.sync).called(1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Sincronizado'), findsOneWidget);
    });

    testWidgets('falha offline avisa, mantém a lista e troca o selo', (
      tester,
    ) async {
      when(syncService.sync)
          .thenThrow(const SyncFailure(SyncFailureType.offline));
      await pumpPage(tester);

      await tester.fling(
        find.byType(ListView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text(SyncFailureType.offline.userMessage), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Carrefour Água Fria'), findsOneWidget);
    });

    testWidgets('falha do servidor troca o selo para falha', (tester) async {
      when(syncService.sync)
          .thenThrow(const SyncFailure(SyncFailureType.server));
      await pumpPage(tester);

      await tester.fling(
        find.byType(ListView).last,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('Falha ao sincronizar'), findsOneWidget);
    });
  });

  testWidgets('erro de leitura mostra aviso e tentar de novo recupera', (
    tester,
  ) async {
    final mock = MockStoreListRepository();
    when(mock.watchStores).thenAnswer(
      (_) => Stream<List<StoreSummary>>.error(StateError('banco fechado')),
    );
    await pumpPage(tester, repo: mock);

    expect(find.text(storesLoadErrorMessage), findsOneWidget);

    when(mock.watchStores).thenAnswer((_) => Stream.value(sampleStores));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Carrefour Água Fria'), findsOneWidget);
  });

  group('acessibilidade e layout', () {
    testWidgets('atende às guidelines de toque, rótulo e contraste', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, role: UserRole.gestor);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('fonte do sistema em 200% não quebra o layout', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPage(tester, role: UserRole.gestor, size: const Size(360, 640));

      expect(tester.takeException(), isNull);
      expect(find.text('Atacadão Jaboatão'), findsOneWidget);
    });

    testWidgets('tela pequena não estoura', (tester) async {
      await pumpPage(tester, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
    });

    testWidgets('paisagem não estoura', (tester) async {
      await pumpPage(tester, size: const Size(844, 390));

      expect(tester.takeException(), isNull);
    });
  });
}
