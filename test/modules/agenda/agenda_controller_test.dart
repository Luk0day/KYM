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
        clock: () => _now,
      );

  setUp(() {
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

  test('lembra o filtro do usuário durante a sessão', () {
    create().selectSituation(AgendaSituationFilter.atrasadas);

    final next = create();

    expect(next.filter.situation, AgendaSituationFilter.atrasadas);
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

  test('resumo conta as vistorias de hoje', () async {
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
