import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/app.dart';
import 'package:kym/app/app_module.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/app/database/seed/fake_data_seeder.dart';
import 'package:kym/modules/agenda/presenter/pages/agenda_page.dart';
import 'package:kym/modules/agenda/presenter/utils/agenda_clock.dart';
import 'package:kym/modules/agenda/presenter/widgets/agenda_filters.dart';
import 'package:kym/modules/auth/infra/datasources/fake_auth_datasource.dart';

const _centro = '00000000-0000-4000-8000-0000000000a1';
const _boaViagem = '00000000-0000-4000-8000-0000000000a2';

final _now = DateTime(2026, 11, 4, 10);

DateTime _day(int offset) =>
    DateTime(_now.year, _now.month, _now.day + offset, 9);

Future<AppDatabase> _database() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await FakeDataSeeder(db).seedIfEmpty();
  await db.delete(db.maintenanceOrders).go();

  Future<void> order(
    String id,
    String equipmentId,
    String storeId, {
    DateTime? date,
    OrderType type = OrderType.preventiva,
    OrderStatus status = OrderStatus.agendada,
    String? assignedTo = FakeDataSeeder.tecnicoId,
    String? description,
  }) => db.maintenanceOrdersDao.upsert(
    MaintenanceOrdersCompanion.insert(
      id: id,
      equipmentId: equipmentId,
      storeId: storeId,
      type: type,
      status: Value(status),
      scheduledFor: Value(date),
      assignedTo: Value(assignedTo),
      description: Value(description),
    ),
  );

  await order(
    'atrasada',
    '00000000-0000-4000-8000-0000000000e2',
    _centro,
    date: _day(-1),
    type: OrderType.corretiva,
    description: 'Câmara fria sem manter a temperatura.',
  );
  await order(
    'hoje',
    '00000000-0000-4000-8000-0000000000e1',
    _centro,
    date: _day(0),
    description: 'Limpeza de filtros.',
  );
  await order(
    'concluida-hoje',
    '00000000-0000-4000-8000-0000000000e3',
    _centro,
    date: _day(0),
    status: OrderStatus.concluida,
  );
  await order(
    'amanha',
    '00000000-0000-4000-8000-0000000000e5',
    _boaViagem,
    date: _day(1),
  );
  await order(
    'outro-tecnico',
    '00000000-0000-4000-8000-0000000000e7',
    _boaViagem,
    date: _day(2),
    assignedTo: 'outro-tecnico',
  );
  await order(
    'sem-data',
    '00000000-0000-4000-8000-0000000000e4',
    _centro,
    type: OrderType.corretiva,
    status: OrderStatus.aberta,
    assignedTo: null,
  );
  return db;
}

Future<void> _openAgenda(
  WidgetTester tester, {
  String email = 'tecnico@kym.test',
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = await tester.runAsync(_database);
  await tester.pumpWidget(
    ModularApp(
      module: AppModule(
        authDataSourceFactory: () => FakeAuthDataSource(latency: Duration.zero),
        databaseFactory: () => db!,
        agendaClock: AgendaClock(() => _now),
      ),
      child: const KymApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), 'kym12345');
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Agenda').last);
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
}

Future<void> _tapDay(WidgetTester tester, DateTime day) async {
  await tester.scrollUntilVisible(
    find.byType(AgendaDayStrip),
    -200,
    scrollable: find.byType(Scrollable).first,
  );
  final box = find.byKey(AgendaDayStrip.keyFor(day));
  await tester.scrollUntilVisible(
    box,
    60,
    scrollable: find.descendant(
      of: find.byType(AgendaDayStrip),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(box);
  await tester.pumpAndSettle();
}

Finder _chip(String label) => find.bySemanticsLabel(label);

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(_chip(label));
  await tester.tap(_chip(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('técnico vê atrasadas e os próximos dias, só as dele', (
    tester,
  ) async {
    await _openAgenda(tester);

    expect(find.byType(AgendaPage), findsOneWidget);
    expect(find.text('Em atraso'), findsOneWidget);
    expect(find.text('Hoje'), findsWidgets);
    expect(find.text('Amanhã'), findsOneWidget);
    expect(find.text('Câmara Fria'), findsOneWidget);
    expect(find.text('Ar-condicionado Salão'), findsOneWidget);
    expect(find.text('Gerador'), findsNothing);
    expect(find.text('Sem data'), findsNothing);
    expect(find.text('CORRETIVA'), findsOneWidget);
    expect(find.text('PREVENTIVA'), findsNWidgets(3));
    expect(find.text('Atrasada'), findsOneWidget);
    expect(find.text('Concluída'), findsOneWidget);
    expect(find.text('Pendente'), findsNWidgets(2));

    await _unmount(tester);
  });

  testWidgets('saudação mostra as visitas de hoje e o progresso', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester);

    expect(find.text('Olá, Técnico Teste'), findsOneWidget);
    expect(find.text('2 visitas programadas hoje'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(
      find.bySemanticsLabel('1 de 2 visitas de hoje concluídas'),
      findsOneWidget,
    );

    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('gestor vê o grupo Sem data e as ordens de todos', (
    tester,
  ) async {
    await _openAgenda(tester, email: 'gestor@kym.test');

    expect(find.text('Sem data'), findsOneWidget);
    expect(find.text('Nobreak'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gerador'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Gerador'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('filtro Atrasadas mostra só o que ficou para trás', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester);

    await _tapChip(tester, 'Atrasadas');

    expect(find.text('Em atraso'), findsOneWidget);
    expect(find.text('Amanhã'), findsNothing);
    expect(find.text('Ar-condicionado Salão'), findsNothing);

    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('filtro Concluídas mostra só as concluídas', (tester) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester);

    await _tapChip(tester, 'Concluídas');

    expect(find.text('Balcão Refrigerado'), findsOneWidget);
    expect(find.text('Câmara Fria'), findsNothing);
    expect(find.text('Em atraso'), findsNothing);

    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('período Hoje esconde os dias seguintes', (tester) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester);

    await _tapChip(tester, 'Hoje');

    expect(find.text('Amanhã'), findsNothing);
    expect(find.text('Em atraso'), findsOneWidget);
    expect(find.text('Ar-condicionado Salão'), findsOneWidget);

    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('tocar num dia da faixa começa o período nele', (tester) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester);
    await _tapChip(tester, 'Hoje');

    await _tapDay(tester, _day(1));
    await tester.pumpAndSettle();

    expect(find.text('Amanhã'), findsOneWidget);
    expect(find.text('Ar-condicionado Salão'), findsNothing);

    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('filtro sem resultado mostra o estado vazio', (tester) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester);
    await _tapChip(tester, 'Pendentes');
    await _tapChip(tester, 'Hoje');

    await _tapDay(tester, _day(5));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma visita pendente no período.'), findsOneWidget);

    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('o filtro escolhido continua ao voltar para a aba', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester);
    await _tapChip(tester, 'Atrasadas');

    await tester.tap(find.text('Painel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agenda').last);
    await tester.pumpAndSettle();

    expect(find.text('Amanhã'), findsNothing);
    expect(find.text('Em atraso'), findsOneWidget);

    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('Personalizado abre o seletor de período em português', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester, size: const Size(1024, 900));

    await _tapChip(tester, 'Personalizado');

    expect(find.text('Escolha o período'), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byType(AgendaPage), findsOneWidget);

    handle.dispose();
    await _unmount(tester);
  });

  testWidgets('celular pequeno com fonte em 200% não quebra', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _openAgenda(tester, size: const Size(320, 640));

    expect(tester.takeException(), isNull);
    expect(find.byType(AgendaPage), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('segue as diretrizes de acessibilidade', (tester) async {
    final handle = tester.ensureSemantics();
    await _openAgenda(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    handle.dispose();
    await _unmount(tester);
  });
}
