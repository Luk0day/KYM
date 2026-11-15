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

  testWidgets('mostra nome, código, cidade e o selo de pendências',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Pão de Açúcar Boa Viagem'), findsOneWidget);
    expect(find.text('L001 · Recife'), findsOneWidget);
    expect(find.text('2 EM ABERTO'), findsOneWidget);
    expect(find.text('EM DIA'), findsOneWidget);
    expect(find.text('Atacadão Jaboatão'), findsNothing);
  });

  testWidgets('gestor vê a loja inativa com o selo', (tester) async {
    await pumpPage(tester, role: UserRole.gestor);

    expect(find.text('Atacadão Jaboatão'), findsOneWidget);
    expect(find.text('INATIVA'), findsOneWidget);
  });

  testWidgets('a busca filtra sem diferenciar acento', (tester) async {
    await pumpPage(tester);

    await search(tester, 'pao de acucar');

    expect(find.text('Pão de Açúcar Boa Viagem'), findsOneWidget);
    expect(find.text('Carrefour Água Fria'), findsNothing);
  });

  testWidgets('sem resultado mostra o aviso e limpar volta a lista',
      (tester) async {
    await pumpPage(tester);

    await search(tester, 'inexistente');

    expect(find.text('Nenhuma loja encontrada'), findsOneWidget);

    await tester.tap(find.text('Limpar busca e filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Carrefour Água Fria'), findsOneWidget);
    expect(find.text('inexistente'), findsNothing);
  });

  testWidgets('sem lojas mostra o estado vazio', (tester) async {
    await pumpPage(tester, repo: FakeStoreListRepository());

    expect(find.text('Nenhuma loja atribuída a você'), findsOneWidget);
  });

  testWidgets('filtro de pendências no BottomSheet', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Só com pendências'));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Pão de Açúcar Boa Viagem'), findsOneWidget);
    expect(find.text('Carrefour Água Fria'), findsNothing);
    expect(find.byTooltip('Filtros (ativos)'), findsOneWidget);
  });

  testWidgets('filtro de cidade no BottomSheet', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Olinda').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Carrefour Água Fria'), findsOneWidget);
    expect(find.text('Pão de Açúcar Boa Viagem'), findsNothing);
  });

  testWidgets('tocar numa loja avisa a rota', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Carrefour Água Fria'));

    expect(selected?.id, 's2');
  });

  testWidgets('puxar para baixo sincroniza', (tester) async {
    await pumpPage(tester);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(syncService.sync).called(1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('falha na sincronização avisa e mantém a lista', (tester) async {
    when(syncService.sync)
        .thenThrow(const SyncFailure(SyncFailureType.offline));
    await pumpPage(tester);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text(SyncFailureType.offline.userMessage), findsOneWidget);
    expect(find.text('Carrefour Água Fria'), findsOneWidget);
  });

  testWidgets('erro de leitura mostra aviso e tentar de novo recupera',
      (tester) async {
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
    testWidgets('atende às guidelines de toque, rótulo e contraste',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, role: UserRole.gestor);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('fonte do sistema em 200% não quebra o layout',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPage(tester, role: UserRole.gestor, size: const Size(360, 640));

      expect(tester.takeException(), isNull);
      expect(find.text('Carrefour Água Fria'), findsOneWidget);
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
