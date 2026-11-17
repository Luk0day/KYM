import 'equipment.dart';

/// Equipamento na lista da loja, com as ordens que pedem atenção.
class EquipmentListItem {
  const EquipmentListItem({
    required this.equipment,
    this.openOrders = 0,
    this.overdueOrders = 0,
  });

  final Equipment equipment;

  /// Ordens abertas, agendadas ou em andamento (inclui as atrasadas).
  final int openOrders;

  /// Parte das abertas cuja data agendada já passou.
  final int overdueOrders;

  bool get hasOpenOrder => openOrders > 0;
  bool get hasOverdueOrder => overdueOrders > 0;
}
