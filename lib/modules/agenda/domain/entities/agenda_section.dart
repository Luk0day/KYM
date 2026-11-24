import '../../../orders/domain/entities/agenda_item.dart';

enum AgendaSectionKind { semData, emAtraso, dia }

class AgendaSection {
  const AgendaSection({required this.kind, required this.items, this.day});

  final AgendaSectionKind kind;
  final List<AgendaItem> items;
  final DateTime? day;
}

class AgendaSummary {
  const AgendaSummary({required this.scheduledToday, required this.doneToday});

  final int scheduledToday;
  final int doneToday;
}
