import '../../../orders/domain/entities/agenda_item.dart';
import '../../../orders/domain/entities/order_situation.dart';
import '../entities/agenda_filter.dart';
import '../entities/agenda_section.dart';

class BuildAgenda {
  /// Monta as seções da agenda na ordem: Sem data, Em atraso e um grupo por
  /// dia dentro do período. As atrasadas ficam sempre em Em atraso, fora do
  /// período, porque são o que ficou para trás. Quem filtra o que cada papel
  /// vê é o [WatchAgenda]: o técnico só recebe as ordens atribuídas a ele.
  List<AgendaSection> call({
    required List<AgendaItem> items,
    required AgendaFilter filter,
    required DateTime today,
  }) {
    final situation = filter.situation;
    final showPending =
        situation == AgendaSituationFilter.todas ||
        situation == AgendaSituationFilter.pendentes;
    final showOverdue =
        situation == AgendaSituationFilter.todas ||
        situation == AgendaSituationFilter.atrasadas;
    final showDone =
        situation == AgendaSituationFilter.todas ||
        situation == AgendaSituationFilter.concluidas;

    final noDate = <AgendaItem>[];
    final overdue = <AgendaItem>[];
    final byDay = <DateTime, List<AgendaItem>>{};

    for (final item in items) {
      final order = item.order;
      final date = order.scheduledFor ?? order.completedAt;

      switch (order.situationOn(today)) {
        case OrderSituation.cancelada:
          continue;
        case OrderSituation.atrasada:
          if (showOverdue) overdue.add(item);
        case OrderSituation.pendente:
          if (!showPending) continue;
          if (date == null) {
            noDate.add(item);
          } else if (filter.contains(date)) {
            byDay.putIfAbsent(dateOnly(date), () => []).add(item);
          }
        case OrderSituation.concluida:
          if (showDone && date != null && filter.contains(date)) {
            byDay.putIfAbsent(dateOnly(date), () => []).add(item);
          }
      }
    }

    overdue.sort(_byDateThenName);
    noDate.sort(_byName);
    final days = byDay.keys.toList()..sort();

    return [
      if (noDate.isNotEmpty)
        AgendaSection(kind: AgendaSectionKind.semData, items: noDate),
      if (overdue.isNotEmpty)
        AgendaSection(kind: AgendaSectionKind.emAtraso, items: overdue),
      for (final day in days)
        AgendaSection(
          kind: AgendaSectionKind.dia,
          day: day,
          items: byDay[day]!..sort(_byName),
        ),
    ];
  }

  AgendaSummary summary({
    required List<AgendaItem> items,
    required DateTime today,
  }) {
    var scheduled = 0;
    var done = 0;
    for (final item in items) {
      final date = item.order.scheduledFor;
      if (date == null || dateOnly(date) != dateOnly(today)) continue;
      final situation = item.order.situationOn(today);
      if (situation == OrderSituation.cancelada) continue;
      scheduled++;
      if (situation == OrderSituation.concluida) done++;
    }
    return AgendaSummary(scheduledToday: scheduled, doneToday: done);
  }

  static int _byName(AgendaItem a, AgendaItem b) =>
      a.equipmentName.compareTo(b.equipmentName);

  static int _byDateThenName(AgendaItem a, AgendaItem b) {
    final byDate = a.order.scheduledFor!.compareTo(b.order.scheduledFor!);
    return byDate != 0 ? byDate : _byName(a, b);
  }
}
