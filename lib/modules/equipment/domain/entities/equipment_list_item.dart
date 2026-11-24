import '../../../orders/domain/entities/maintenance_order.dart';
import 'equipment.dart';

/// Equipamento na lista da loja, com o que a tela precisa saber das ordens.
class EquipmentListItem {
  const EquipmentListItem({
    required this.equipment,
    this.openOrders = 0,
    this.overdueOrders = 0,
    this.nextOrderType,
    this.lastMaintenanceAt,
  });

  final Equipment equipment;

  /// Ordens abertas, agendadas ou em andamento (inclui as atrasadas).
  final int openOrders;

  /// Parte das abertas cuja data agendada já passou.
  final int overdueOrders;

  /// Tipo da ordem aberta mais urgente (atrasada primeiro, depois a de data
  /// mais próxima). `null` se não há ordem aberta.
  final OrderType? nextOrderType;

  /// Conclusão da última manutenção feita. `null` se nunca houve.
  final DateTime? lastMaintenanceAt;

  bool get hasOpenOrder => openOrders > 0;
  bool get hasOverdueOrder => overdueOrders > 0;
}
