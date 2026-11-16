import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/agenda/domain/entities/agenda_filter.dart';
import 'package:kym/modules/agenda/domain/entities/agenda_section.dart';
import 'package:kym/modules/agenda/domain/usecases/build_agenda.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/orders/domain/entities/agenda_item.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart';
import 'package:kym/modules/orders/domain/entities/order_situation.dart';

final _today = DateTime(2026, 11, 4, 15, 30);

AgendaItem _item(
  String name, {
  DateTime? date,
  OrderStatus status = OrderStatus.agendada,
  OrderType type = OrderType.preventiva,
  DateTime? completedAt,
}) => AgendaItem(
  equipmentName: name,
  storeName: 'Loja Centro',
  order: MaintenanceOrder(
    id: name,
    equipmentId: 'eq-$name',
    storeId: 'loja',
    type: type,
    status: status,
    scheduledFor: date,
    completedAt: completedAt,
    createdAt: DateTime(2026, 10, 1),
    updatedAt: DateTime(2026, 10, 1),
  ),
);

DateTime _day(int offset) => DateTime(2026, 11, 4 + offset, 9);

void main() {
  group('OrderSituation', () {
    OrderSituation situation(
      DateTime? date, {
      OrderStatus status = OrderStatus.agendada,
    }) => _item('x', date: date, status: status).order.situationOn(_today);

    test('pendente de hoje (mesmo com hora anterior) não está atrasada', () {
      expect(situation(DateTime(2026, 11, 4, 8)), OrderSituation.pendente);
    });

    test('pendente de ontem está atrasada', () {
      expect(situation(DateTime(2026, 11, 3, 23, 59)), OrderSituation.atrasada);
    });

    test('pendente de amanhã é pendente', () {
      expect(situation(_day(1)), OrderSituation.pendente);
    });

    test('sem data nunca fica atrasada', () {
      expect(
        situation(null, status: OrderStatus.aberta),
        OrderSituation.pendente,
      );
    });

    test('em andamento de ontem também está atrasada', () {
      expect(
        situation(_day(-1), status: OrderStatus.emAndamento),
        OrderSituation.atrasada,
      );
    });

    test('concluída de ontem continua concluída', () {
      expect(
        situation(_day(-1), status: OrderStatus.concluida),
        OrderSituation.concluida,
      );
    });

    test('cancelada é cancelada', () {
      expect(
        situation(_day(1), status: OrderStatus.cancelada),
        OrderSituation.cancelada,
      );
    });
  });

  group('AgendaFilter', () {
    test('hoje cobre só o dia de início', () {
      final filter = AgendaFilter(start: _today, period: AgendaPeriod.hoje);
      expect(filter.contains(_day(0)), isTrue);
      expect(filter.contains(_day(1)), isFalse);
    });

    test('7 dias cobre o início e os 6 seguintes', () {
      final filter = AgendaFilter(start: _today);
      expect(filter.end, DateTime(2026, 11, 10));
      expect(filter.contains(_day(6)), isTrue);
      expect(filter.contains(_day(7)), isFalse);
      expect(filter.contains(_day(-1)), isFalse);
    });

    test('30 dias atravessa o mês', () {
      final filter = AgendaFilter(
        start: _today,
        period: AgendaPeriod.trintaDias,
      );
      expect(filter.end, DateTime(2026, 12, 3));
    });

    test('personalizado usa o fim escolhido', () {
      final filter = AgendaFilter(
        start: _today,
        period: AgendaPeriod.personalizado,
        customEnd: DateTime(2026, 11, 20, 18),
      );
      expect(filter.end, DateTime(2026, 11, 20));
    });

    test('personalizado sem fim vale só o dia de início', () {
      final filter = AgendaFilter(
        start: _today,
        period: AgendaPeriod.personalizado,
      );
      expect(filter.end, DateTime(2026, 11, 4));
    });

    test('copyWith troca só o que foi pedido', () {
      final filter = AgendaFilter(start: _today)
          .copyWith(situation: AgendaSituationFilter.concluidas);
      expect(filter.situation, AgendaSituationFilter.concluidas);
      expect(filter.period, AgendaPeriod.seteDias);
      expect(filter.start, DateTime(2026, 11, 4));
    });
  });

  group('BuildAgenda', () {
    final build = BuildAgenda();

    final items = [
      _item('Freezer', date: _day(-1), type: OrderType.corretiva),
      _item('Ar-condicionado', date: _day(0)),
      _item('Câmara fria', date: _day(1)),
      _item('Iluminação', date: _day(2)),
      _item('Gerador', date: _day(20)),
      _item(
        'Balcão',
        date: _day(0),
        status: OrderStatus.concluida,
        completedAt: _day(0),
      ),
      _item('Exaustor', date: _day(1), status: OrderStatus.cancelada),
      _item('Chamado', status: OrderStatus.aberta, type: OrderType.corretiva),
    ];

    List<AgendaSection> sections({
      AgendaSituationFilter situation = AgendaSituationFilter.todas,
      AgendaPeriod period = AgendaPeriod.seteDias,
      UserRole role = UserRole.tecnico,
    }) => build(
      items: items,
      filter: AgendaFilter(start: _today, situation: situation, period: period),
      today: _today,
      role: role,
    );

    List<String> names(AgendaSection section) =>
        section.items.map((i) => i.equipmentName).toList();

    test('técnico: Em atraso e um grupo por dia, sem canceladas', () {
      final result = sections();

      expect(result.map((s) => s.kind), [
        AgendaSectionKind.emAtraso,
        AgendaSectionKind.dia,
        AgendaSectionKind.dia,
        AgendaSectionKind.dia,
      ]);
      expect(names(result[0]), ['Freezer']);
      expect(result[1].day, DateTime(2026, 11, 4));
      expect(names(result[1]), ['Ar-condicionado', 'Balcão']);
      expect(names(result[2]), ['Câmara fria']);
      expect(names(result[3]), ['Iluminação']);
    });

    test('gestor vê o grupo Sem data no topo', () {
      final result = sections(role: UserRole.gestor);

      expect(result.first.kind, AgendaSectionKind.semData);
      expect(names(result.first), ['Chamado']);
    });

    test('ordens fora do período não aparecem nos dias', () {
      final all = sections(period: AgendaPeriod.trintaDias);
      final week = sections();

      bool hasGerador(List<AgendaSection> s) =>
          s.any((section) => names(section).contains('Gerador'));
      expect(hasGerador(all), isTrue);
      expect(hasGerador(week), isFalse);
    });

    test('atrasadas aparecem mesmo com o período em hoje', () {
      final result = sections(period: AgendaPeriod.hoje);

      expect(result.first.kind, AgendaSectionKind.emAtraso);
      expect(result.length, 2);
    });

    test('filtro pendentes tira atrasadas e concluídas', () {
      final result = sections(situation: AgendaSituationFilter.pendentes);

      expect(result.any((s) => s.kind == AgendaSectionKind.emAtraso), isFalse);
      expect(result.expand(names), isNot(contains('Balcão')));
    });

    test('filtro atrasadas mostra só Em atraso', () {
      final result = sections(situation: AgendaSituationFilter.atrasadas);

      expect(result.single.kind, AgendaSectionKind.emAtraso);
    });

    test('filtro concluídas mostra só as concluídas do período', () {
      final result = sections(situation: AgendaSituationFilter.concluidas);

      expect(result.single.kind, AgendaSectionKind.dia);
      expect(names(result.single), ['Balcão']);
    });

    test('lista vazia devolve nenhuma seção', () {
      expect(
        build(
          items: const [],
          filter: AgendaFilter(start: _today),
          today: _today,
          role: UserRole.gestor,
        ),
        isEmpty,
      );
    });

    test('resumo conta as visitas de hoje e as concluídas', () {
      final summary = build.summary(items: items, today: _today);

      expect(summary.scheduledToday, 2);
      expect(summary.doneToday, 1);
    });
  });
}
