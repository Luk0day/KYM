import '../../../orders/domain/entities/maintenance_order.dart';
import '../../../stores/domain/entities/store.dart';
import 'equipment.dart';

/// Quantas ordens o histórico mostra antes do "Ver todas".
const int equipmentHistoryPreviewLimit = 20;

/// Equipamento com a loja e o histórico de manutenções (mais recente primeiro).
class EquipmentDetail {
  const EquipmentDetail({
    required this.equipment,
    required this.history,
    this.store,
  });

  final Equipment equipment;

  /// `null` se a loja ainda não chegou ao banco local.
  final Store? store;
  final List<MaintenanceOrder> history;

  List<MaintenanceOrder> get recentHistory =>
      history.length <= equipmentHistoryPreviewLimit
      ? history
      : history.sublist(0, equipmentHistoryPreviewLimit);

  bool get hasMoreHistory => history.length > equipmentHistoryPreviewLimit;

  /// Ordem em aberto atribuída ao usuário (libera "Registrar manutenção").
  bool hasOpenOrderAssignedTo(String userId) => history.any(
    (o) =>
        o.assignedTo == userId &&
        (o.status == OrderStatus.aberta ||
            o.status == OrderStatus.agendada ||
            o.status == OrderStatus.emAndamento),
  );

  /// Próxima manutenção preventiva: a data agendada mais próxima entre as
  /// preventivas em aberto. `null` se não houver nenhuma agendada.
  DateTime? get nextPreventive {
    DateTime? next;
    for (final o in history) {
      final due = o.scheduledFor;
      if (o.type != OrderType.preventiva || due == null || !_isOpen(o.status)) {
        continue;
      }
      if (next == null || due.isBefore(next)) next = due;
    }
    return next;
  }

  static bool _isOpen(OrderStatus s) =>
      s == OrderStatus.aberta ||
      s == OrderStatus.agendada ||
      s == OrderStatus.emAndamento;

  /// Data usada para ordenar e exibir a ordem no histórico.
  static DateTime orderDate(MaintenanceOrder o) =>
      o.completedAt ?? o.scheduledFor ?? o.createdAt;
}
