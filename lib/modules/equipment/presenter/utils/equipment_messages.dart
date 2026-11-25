import '../../../orders/domain/entities/maintenance_order.dart';
import '../../domain/entities/equipment_status.dart';

const String equipmentLoadErrorMessage =
    'Não foi possível carregar os equipamentos. Tente novamente.';
const String equipmentEmptyMessage = 'Nenhum equipamento cadastrado nesta loja';

String equipmentStatusLabel(EquipmentStatus status) => switch (status) {
  EquipmentStatus.operando => 'Operando',
  EquipmentStatus.emManutencao => 'Em manutenção',
  EquipmentStatus.parado => 'Parado',
};

String equipmentCountLabel(int n) =>
    n == 1 ? '1 equipamento' : '$n equipamentos';

String openOrdersLabel(int open, int overdue) {
  if (overdue > 0) {
    return overdue == 1 ? '1 ordem atrasada' : '$overdue ordens atrasadas';
  }
  return open == 1 ? '1 ordem aberta' : '$open ordens abertas';
}

/// Iniciais do equipamento no Figma: prefixo do código de série (ex.:
/// "AC-0012" -> "AC"). Sem série, as duas primeiras letras do nome.
String equipmentInitials(String? serialNumber, String name) {
  final serial = serialNumber?.trim() ?? '';
  final prefix = RegExp(r'^[A-Za-zÀ-ú]{1,2}').stringMatch(serial);
  final source = prefix ?? name.trim();
  if (source.isEmpty) return '';
  final end = source.length < 2 ? source.length : 2;
  return source.substring(0, end).toUpperCase();
}

String formatDate(DateTime value) {
  final d = value.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// "Hoje, 14:00", "Amanhã, 09:00" ou "05/11, 10:30" (Figma: Próxima preventiva).
String formatWhen(DateTime value, DateTime now) {
  final d = value.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Hoje, $hh:$mm';
  if (diff == 1) return 'Amanhã, $hh:$mm';
  final dd = d.day.toString().padLeft(2, '0');
  final mo = d.month.toString().padLeft(2, '0');
  return '$dd/$mo, $hh:$mm';
}

String orderTypeLabel(OrderType type) => switch (type) {
  OrderType.preventiva => 'Preventiva',
  OrderType.corretiva => 'Corretiva',
};

String lastMaintenanceLabel(DateTime? date) => date == null
    ? 'Sem manutenção registrada'
    : 'Última manutenção: ${formatDate(date)}';
