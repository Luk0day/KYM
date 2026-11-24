import '../../../orders/domain/entities/order_situation.dart';

abstract final class AgendaDates {
  static const _weekdaysShort = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom',
  ];
  static const _weekdays = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  static const _months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static String weekdayShort(DateTime date) => _weekdaysShort[date.weekday - 1];

  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  static String monthYear(DateTime date) =>
      '${_months[date.month - 1]} de ${date.year}';

  static String dayMonth(DateTime date) =>
      '${date.day} ${_months[date.month - 1].substring(0, 3)}';

  static String relative(DateTime date, DateTime today) {
    final diff = dateOnly(date).difference(dateOnly(today)).inDays;
    return switch (diff) {
      0 => 'Hoje',
      1 => 'Amanhã',
      -1 => 'Ontem',
      _ => '${weekday(date)}, ${dayMonth(date)}',
    };
  }

  static String shortRelative(DateTime date, DateTime today) {
    final diff = dateOnly(date).difference(dateOnly(today)).inDays;
    return switch (diff) {
      0 => 'Hoje',
      1 => 'Amanhã',
      -1 => 'Ontem',
      _ => '${weekdayShort(date)}, ${dayMonth(date)}',
    };
  }
}
