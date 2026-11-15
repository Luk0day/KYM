enum OrderType { preventiva, corretiva }

enum OrderStatus { aberta, agendada, emAndamento, concluida, cancelada }

/// Ordem de manutenção (preventiva ou chamado corretivo). Dart puro.
class MaintenanceOrder {
  const MaintenanceOrder({
    required this.id,
    required this.equipmentId,
    required this.storeId,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.notes,
    this.scheduledFor,
    this.openedBy,
    this.assignedTo,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String equipmentId;
  final String storeId;
  final OrderType type;
  final OrderStatus status;
  final String? description;
  final String? notes;
  final DateTime? scheduledFor;
  final String? openedBy;
  final String? assignedTo;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Dados para criar uma ordem; o id e as datas são gerados pelo repositório.
class NewOrder {
  const NewOrder({
    required this.equipmentId,
    required this.storeId,
    required this.type,
    this.status = OrderStatus.aberta,
    this.description,
    this.scheduledFor,
    this.openedBy,
    this.assignedTo,
  });

  final String equipmentId;
  final String storeId;
  final OrderType type;
  final OrderStatus status;
  final String? description;
  final DateTime? scheduledFor;
  final String? openedBy;
  final String? assignedTo;
}
