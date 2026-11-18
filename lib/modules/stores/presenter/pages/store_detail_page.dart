import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_banner.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../../../../shared/presenter/widgets/kym_chip.dart';
import '../../../equipment/domain/entities/equipment.dart';
import '../../../equipment/presenter/controllers/equipment_list_controller.dart';
import '../../../equipment/presenter/widgets/equipment_list.dart';
import '../../domain/entities/store.dart';
import '../controllers/store_detail_controller.dart';
import '../widgets/store_map.dart';
import '../widgets/store_map_fallback.dart';

const String storeNotFoundMessage =
    'Loja não encontrada. Ela pode ter sido removida ou não estar mais atribuída a você.';
const String storeLoadErrorMessage =
    'Não foi possível carregar a loja. Tente novamente.';

/// Tela 5: dados da loja, mapa, equipamentos (B27) e check-in (B33).
class StoreDetailPage extends StatefulWidget {
  const StoreDetailPage({
    super.key,
    required this.storeId,
    required this.controller,
    required this.equipmentController,
    required this.onBack,
    required this.onEquipmentSelected,
    this.canCheckIn = false,
    this.onCheckIn,
  });

  final String storeId;
  final StoreDetailController controller;
  final EquipmentListController equipmentController;
  final VoidCallback onBack;
  final ValueChanged<Equipment> onEquipmentSelected;

  /// Só o técnico vê o botão de check-in (B15).
  final bool canCheckIn;

  /// `null` deixa o botão desabilitado até a B33 existir.
  final VoidCallback? onCheckIn;

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: widget.onBack,
        ),
        title: Semantics(
          header: true,
          child: const Text('Loja', style: AppTextStyles.sectionTitle),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => switch (widget.controller.status) {
            StoreDetailStatus.loading => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando loja',
              ),
            ),
            StoreDetailStatus.notFound => _Message(
              text: storeNotFoundMessage,
              action: KymButton(label: 'Voltar', onPressed: widget.onBack),
            ),
            StoreDetailStatus.error => _Message(
              text: storeLoadErrorMessage,
              isError: true,
              action: KymButton(
                label: 'Tentar novamente',
                onPressed: widget.controller.retry,
              ),
            ),
            StoreDetailStatus.ready => _Content(
              store: widget.controller.store!,
              equipmentController: widget.equipmentController,
              onEquipmentSelected: widget.onEquipmentSelected,
              canCheckIn: widget.canCheckIn,
              onCheckIn: widget.onCheckIn,
            ),
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.action,
    this.isError = false,
  });

  final String text;
  final Widget action;
  final bool isError;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isError)
          KymBanner(message: text)
        else
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        const SizedBox(height: 16),
        action,
      ],
    ),
  );
}

class _Content extends StatelessWidget {
  const _Content({
    required this.store,
    required this.equipmentController,
    required this.onEquipmentSelected,
    required this.canCheckIn,
    required this.onCheckIn,
  });

  final Store store;
  final EquipmentListController equipmentController;
  final ValueChanged<Equipment> onEquipmentSelected;
  final bool canCheckIn;
  final VoidCallback? onCheckIn;

  String? get _address {
    final parts = [store.address, store.city]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final address = _address;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(store.name, style: AppTextStyles.screenTitle),
        if (store.code != null)
          Text('Código ${store.code}', style: AppTextStyles.metadata),
        // Sem coordenadas, o endereço já aparece no quadro que ocupa o mapa.
        if (store.hasCoordinates)
          Text(address ?? 'Endereço não informado', style: AppTextStyles.body),
        if (!store.active) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: KymChip(label: 'Inativa', tone: KymChipTone.neutral),
          ),
        ],
        const SizedBox(height: 16),
        if (store.hasCoordinates)
          StoreMap(
            latitude: store.latitude!,
            longitude: store.longitude!,
            storeName: store.name,
            address: address,
          )
        else
          StoreMapFallback(address: address),
        if (canCheckIn) ...[
          const SizedBox(height: 16),
          // TODO(B33): ligar ao check-in/check-out pelo leitor de QR.
          KymButton(label: 'Fazer check-in', onPressed: onCheckIn),
        ],
        const SizedBox(height: 24),
        EquipmentList(
          storeId: store.id,
          controller: equipmentController,
          onEquipmentSelected: onEquipmentSelected,
        ),
      ],
    );
  }
}
