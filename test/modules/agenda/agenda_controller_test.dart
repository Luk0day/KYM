import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/agenda/domain/entities/agenda_filter.dart';
import 'package:kym/modules/agenda/domain/usecases/build_agenda.dart';
import 'package:kym/modules/agenda/domain/usecases/watch_agenda.dart';
import 'package:kym/modules/agenda/presenter/controllers/agenda_controller.dart';
import 'package:kym/modules/auth/domain/entities/authenticated_user.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/orders/domain/entities/agenda_item.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart';
import 'package:kym/modules/orders/domain/repositories/order_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockOrderRepository extends Mock implements OrderRepository {}

final _now = DateTime(2026, 11, 15, 10);
var _clock = _now;

const _tecnico = AuthenticatedUser(
  id: 'tec',
  email: 'tecnico@kym.test',
  role: UserRole.tecnico,
);

AgendaItem _item(String name, DateTime date) => AgendaItem(
  equipmentName: name,
  storeName: 'Loja Centro',
  order: MaintenanceOrder(
    id: name,
    equipmentId: 'eq',
    storeId: 'loja',
    type: OrderType.preventiva,
    status: OrderStatus.agendada,
    scheduledFor: date,
    assignedTo: 'tec',
    createdAt: _now,
    updatedAt: _now,
  ),
);

void main() {
  late _MockOrderRepository repository;
  late StreamController<List<AgendaItem>> items;
  late AgendaFilterMemory memory;

  AgendaController create({AuthenticatedUser user = _tecnico}) =>
      AgendaController(
        WatchAgenda(repository),
        BuildAgenda(),
        memory,
        user,
        clock: () => _clock,
      );

  setUp(() {
    _clock = _now;
    repository = _MockOrderRepository();
    items = StreamController<List<AgendaItem>>.broadcast();
    memory = AgendaFilterMemory();
    when(() => repository.watchAgenda(assignedTo: any(named: 'assignedTo')))
        .thenAnswer((_) => items.stream);
  });

  tearDown(() => items.close());

  test('começa carregando, com 7 dias a partir de hoje', () {
    final controller = create();

    expect(controller.status, AgendaStatus.loading);
    expect(controller.filter.period, AgendaPeriod.seteDias);
    expect(controller.filter.start, DateTime(2026, 11, 15));
    controller.dispose();
  });

  test('técnico pede só as ordens atribuídas a ele', () {
    create().start();

    verify(() => repository.watchAgenda(assignedTo: 'tec')).called(1);
  });

  test('gestor pede todas as ordens', () {
    create(
      user: const AuthenticatedUser(
        id: 'ges',
        email: 'gestor@kym.test',
        role: UserRole.gestor,
      ),
    ).start();

    verify(() => repository.watchAgenda()).called(1);
  });

  test('fica pronto e monta as seções quando os dados chegam', () async {
    final controller = create()..start();

    items.add([_item('Ar-condicionado', DateTime(2026, 11, 16))]);
    await pumpEventQueue();

    expect(controller.status, AgendaStatus.ready);
    expect(
      controller.sections.single.items.single.equipmentName,
      'Ar-condicionado',
    );
    controller.dispose();
  });

  test(
    'erro no banco mostra o estado de erro e tentar de novo recarrega',
    () async {
      final controller = create()..start();

      items.addError(StateError('falhou'));
      await pumpEventQueue();
      expect(controller.status, AgendaStatus.error);

      controller.start();
      expect(controller.status, AgendaStatus.loading);
      items.add(const []);
      await pumpEventQueue();
      expect(controller.status, AgendaStatus.ready);
      controller.dispose();
    },
  );

  test('refresh recarrega sem trocar a lista pelo carregando', () async {
    final controller = create()..start();
    items.add([_item('Ar-condicionado', DateTime(2026, 11, 16))]);
    await pumpEventQueue();

    controller.refresh();

    expect(controller.status, AgendaStatus.ready);
    expect(controller.sections, isNotEmpty);
    verify(() => repository.watchAgenda(assignedTo: 'tec')).called(2);
    controller.dispose();
  });

  test('refresh depois de um erro volta a carregar', () async {
    final controller = create()..start();
    items.addError(StateError('falhou'));
    await pumpEventQueue();

    controller.refresh();

    expect(controller.status, AgendaStatus.loading);
    controller.dispose();
  });

  test('lembra o filtro do usuário durante a sessão', () {
    create().selectSituation(AgendaSituationFilter.atrasadas);

    final next = create();

    expect(next.filter.situation, AgendaSituationFilter.atrasadas);
  });

  group('filtro lembrado de outro dia', () {
    test('início no passado vira hoje, com situação e período', () {
      create()
        ..selectSituation(AgendaSituationFilter.pendentes)
        ..selectPeriod(AgendaPeriod.trintaDias);

      _clock = DateTime(2026, 11, 16, 7);
      final next = create();

      expect(next.filter.start, DateTime(2026, 11, 16));
      expect(next.filter.period, AgendaPeriod.trintaDias);
      expect(next.filter.situation, AgendaSituationFilter.pendentes);
    });

    test('início no futuro continua igual', () {
      create().selectDay(DateTime(2026, 11, 20));

      _clock = DateTime(2026, 11, 16, 7);

      expect(create().filter.start, DateTime(2026, 11, 20));
    });

    test('Personalizado em andamento mantém o fim', () {
      create().selectRange(DateTime(2026, 11, 14), DateTime(2026, 11, 22));

      _clock = DateTime(2026, 11, 16, 7);
      final filter = create().filter;

      expect(filter.period, AgendaPeriod.personalizado);
      expect(filter.start, DateTime(2026, 11, 16));
      expect(filter.end, DateTime(2026, 11, 22));
    });

    test('Personalizado que já terminou volta para o padrão', () {
      create()
        ..selectSituation(AgendaSituationFilter.concluidas)
        ..selectRange(DateTime(2026, 11, 10), DateTime(2026, 11, 15));

      _clock = DateTime(2026, 11, 16, 7);
      final filter = create().filter;

      expect(filter.period, AgendaPeriod.seteDias);
      expect(filter.start, DateTime(2026, 11, 16));
      expect(filter.situation, AgendaSituationFilter.concluidas);
    });

    test('app aberto de um dia para o outro passa para o dia novo', () {
      final controller = create();

      _clock = DateTime(2026, 11, 16, 0, 5);

      expect(controller.filter.start, DateTime(2026, 11, 16));
      expect(controller.filter.period, AgendaPeriod.seteDias);
    });

    test('dia passado escolhido hoje continua ao voltar para a aba', () {
      create().selectDay(DateTime(2026, 11, 12));

      expect(create().filter.start, DateTime(2026, 11, 12));
    });
  });

  test('selecionar período mantém a situação e o dia', () {
    final controller = create()
      ..selectSituation(AgendaSituationFilter.concluidas)
      ..selectDay(DateTime(2026, 11, 18))
      ..selectPeriod(AgendaPeriod.trintaDias);

    expect(controller.filter.situation, AgendaSituationFilter.concluidas);
    expect(controller.filter.start, DateTime(2026, 11, 18));
    expect(controller.filter.end, DateTime(2026, 12, 17));
  });

  test('Personalizado só vale com um intervalo escolhido', () {
    final controller = create()..selectPeriod(AgendaPeriod.personalizado);

    expect(controller.filter.period, AgendaPeriod.seteDias);

    controller.selectRange(DateTime(2026, 11, 20), DateTime(2026, 11, 28));

    expect(controller.filter.period, AgendaPeriod.personalizado);
    expect(controller.filter.start, DateTime(2026, 11, 20));
    expect(controller.filter.end, DateTime(2026, 11, 28));
  });

  test('Hoje volta o início para hoje', () {
    final controller = create()
      ..selectDay(DateTime(2026, 11, 20))
      ..selectPeriod(AgendaPeriod.hoje);

    expect(controller.filter.period, AgendaPeriod.hoje);
    expect(controller.filter.start, DateTime(2026, 11, 15));
    expect(controller.filter.end, DateTime(2026, 11, 15));
  });

  test('7 e 30 dias continuam a partir do dia escolhido', () {
    final controller = create()
      ..selectPeriod(AgendaPeriod.hoje)
      ..selectDay(DateTime(2026, 11, 20))
      ..selectPeriod(AgendaPeriod.seteDias);

    expect(controller.filter.start, DateTime(2026, 11, 20));
    expect(controller.filter.end, DateTime(2026, 11, 26));

    controller.selectPeriod(AgendaPeriod.trintaDias);

    expect(controller.filter.start, DateTime(2026, 11, 20));
    expect(controller.filter.end, DateTime(2026, 12, 19));
  });

  test('tocar num dia com período personalizado volta para 7 dias', () {
    final controller = create()
      ..selectRange(DateTime(2026, 11, 20), DateTime(2026, 11, 28))
      ..selectDay(DateTime(2026, 11, 22));

    expect(controller.filter.period, AgendaPeriod.seteDias);
    expect(controller.filter.start, DateTime(2026, 11, 22));
    expect(controller.filter.end, DateTime(2026, 11, 28));
  });

  test('a faixa começa numa segunda e inclui um dia passado escolhido', () {
    final controller = create()..selectDay(DateTime(2026, 10, 20));
    final days = controller.stripDays;

    expect(days.first.weekday, DateTime.monday);
    expect(days, contains(DateTime(2026, 10, 20)));
    expect(days, contains(DateTime(2026, 11, 15)));
  });

  test('resumo conta as visitas de hoje', () async {
    final controller = create()..start();

    items.add([
      _item('A', DateTime(2026, 11, 15, 8)),
      _item('B', DateTime(2026, 11, 16)),
    ]);
    await pumpEventQueue();

    expect(controller.summary.scheduledToday, 1);
    controller.dispose();
  });

  test('não avisa depois de descartado', () async {
    final controller = create()..start();
    controller.dispose();

    items.add(const []);
    await pumpEventQueue();
  });
}
