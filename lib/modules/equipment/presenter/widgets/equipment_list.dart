import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_banner.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../../domain/entities/equipment.dart';
import '../controllers/equipment_list_controller.dart';
import '../utils/equipment_messages.dart';
import 'equipment_tile.dart';

/// Equipamentos de uma loja (componente, sem rolagem própria). A tela de
/// detalhes da loja (B26) só encaixa este widget.
class EquipmentList extends StatefulWidget {
  const EquipmentList({
    super.key,
    required this.storeId,
    required this.controller,
    required this.onEquipmentSelected,
  });

  final String storeId;
  final EquipmentListController controller;
  final ValueChanged<Equipment> onEquipmentSelected;

  @override
  State<EquipmentList> createState() => _EquipmentListState();
}

class _EquipmentListState extends State<EquipmentList> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.storeId);
  }

  @override
  void didUpdateWidget(EquipmentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeId != widget.storeId) {
      widget.controller.load(widget.storeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final ready = c.status == EquipmentListStatus.ready;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                ready
                    ? 'Equipamentos · ${equipmentCountLabel(c.items.length)}'
                    : 'Equipamentos',
                style: AppTextStyles.sectionTitle,
              ),
            ),
            const SizedBox(height: 12),
            switch (c.status) {
              EquipmentListStatus.loading => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando equipamentos',
                  ),
                ),
              ),
              EquipmentListStatus.error => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KymBanner(message: equipmentLoadErrorMessage),
                  const SizedBox(height: 12),
                  KymButton(label: 'Tentar novamente', onPressed: c.retry),
                ],
              ),
              EquipmentListStatus.ready when c.items.isEmpty => Text(
                equipmentEmptyMessage,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              EquipmentListStatus.ready => Column(
                children: [
                  for (final item in c.items) ...[
                    EquipmentTile(
                      item: item,
                      onTap: () => widget.onEquipmentSelected(item.equipment),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            },
          ],
        );
      },
    );
  }
}
