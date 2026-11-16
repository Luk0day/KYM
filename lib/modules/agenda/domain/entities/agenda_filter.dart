import '../../../orders/domain/entities/order_situation.dart';

enum AgendaSituationFilter { todas, pendentes, atrasadas, concluidas }

enum AgendaPeriod { hoje, seteDias, trintaDias, personalizado }

class AgendaFilter {
  AgendaFilter({
    this.situation = AgendaSituationFilter.todas,
    this.period = AgendaPeriod.seteDias,
    required DateTime start,
    DateTime? customEnd,
  }) : start = dateOnly(start),
       customEnd = customEnd == null ? null : dateOnly(customEnd);

  final AgendaSituationFilter situation;
  final AgendaPeriod period;
  final DateTime start;
  final DateTime? customEnd;

  DateTime get end => switch (period) {
    AgendaPeriod.hoje => start,
    AgendaPeriod.seteDias => _addDays(start, 6),
    AgendaPeriod.trintaDias => _addDays(start, 29),
    AgendaPeriod.personalizado => customEnd ?? start,
  };

  bool contains(DateTime date) {
    final day = dateOnly(date);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  AgendaFilter copyWith({
    AgendaSituationFilter? situation,
    AgendaPeriod? period,
    DateTime? start,
    DateTime? customEnd,
  }) => AgendaFilter(
    situation: situation ?? this.situation,
    period: period ?? this.period,
    start: start ?? this.start,
    customEnd: customEnd ?? this.customEnd,
  );

  static DateTime _addDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);
}
