import 'maintenance_order.dart';

enum OrderSituation { pendente, atrasada, concluida, cancelada }

DateTime dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

extension MaintenanceOrderSituation on MaintenanceOrder {
  /// Regra única de situação, usada pela agenda, pelo painel (B45) e pelas
  /// notificações (B49). Atrasada é a pendente com data antes de [today];
  /// sem data nunca fica atrasada.
  OrderSituation situationOn(DateTime today) {
    switch (status) {
      case OrderStatus.concluida:
        return OrderSituation.concluida;
      case OrderStatus.cancelada:
        return OrderSituation.cancelada;
      case OrderStatus.aberta:
      case OrderStatus.agendada:
      case OrderStatus.emAndamento:
        final date = scheduledFor;
        if (date != null && dateOnly(date).isBefore(dateOnly(today))) {
          return OrderSituation.atrasada;
        }
        return OrderSituation.pendente;
    }
  }
}
