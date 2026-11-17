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

/// Até duas letras da categoria (ex.: "Refrigeração" -> "RE").
String categoryInitials(String? category) {
  final text = category?.trim() ?? '';
  if (text.isEmpty) return '';
  final end = text.length < 2 ? text.length : 2;
  return text.substring(0, end).toUpperCase();
}

String formatDate(DateTime value) {
  final d = value.toLocal();
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
