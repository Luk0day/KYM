import 'package:flutter/material.dart';

import '../../../../shared/presenter/widgets/kym_chip.dart';
import '../../domain/entities/equipment_status.dart';
import '../utils/equipment_messages.dart';

class EquipmentStatusChip extends StatelessWidget {
  const EquipmentStatusChip({super.key, required this.status});

  final EquipmentStatus status;

  KymChipTone get _tone => switch (status) {
    EquipmentStatus.operando => KymChipTone.done,
    EquipmentStatus.emManutencao => KymChipTone.pending,
    EquipmentStatus.parado => KymChipTone.overdue,
  };

  @override
  Widget build(BuildContext context) =>
      KymChip(label: equipmentStatusLabel(status), tone: _tone);
}
