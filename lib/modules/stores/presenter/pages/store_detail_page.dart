import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_back_link.dart';
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
const String checkInLabel = 'Fazer check-in (ler QR da loja)';

/// Tela 5 (Figma): voltar, nome e endereço, mapa, equipamentos (B27) e o
/// botão de check-in fixo no rodapé (B33).
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
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final store = widget.controller.store;
            final ready =
                widget.controller.status == StoreDetailStatus.ready &&
                store != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 20, 0),
                  child: KymBackLink(label: 'Lojas', onPressed: widget.onBack),
                ),
                if (ready) _Header(store: store),
                Expanded(child: _body(store)),
                if (ready && widget.canCheckIn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: KymButton(
                      label: checkInLabel,
                      leading: const Icon(Icons.qr_code_scanner, size: 20),
                      // TODO(B33): abrir o leitor para check-in/check-out.
                      onPressed: widget.onCheckIn,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(Store? store) => switch (widget.controller.status) {
    StoreDetailStatus.loading => const Center(
      child: CircularProgressIndicator(semanticsLabel: 'Carregando loja'),
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
      store: store!,
      equipmentController: widget.equipmentController,
      onEquipmentSelected: widget.onEquipmentSelected,
    ),
  };
}

String? storeAddressLine(Store store) {
  final parts = [store.address, store.city]
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return parts.isEmpty ? null : parts.join(' · ');
}

class _Header extends StatelessWidget {
  const _Header({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final address = storeAddressLine(store);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(store.name, style: AppTextStyles.screenTitle),
          ),
          if (address != null && store.hasCoordinates) ...[
            const SizedBox(height: 4),
            Text(address, style: AppTextStyles.metadata),
          ],
          if (store.code != null)
            Text('Código ${store.code}', style: AppTextStyles.metadata),
          if (!store.active) ...[
            const SizedBox(height: 8),
            const KymChip(label: 'Inativa', tone: KymChipTone.neutral),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
        ],
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
  });

  final Store store;
  final EquipmentListController equipmentController;
  final ValueChanged<Equipment> onEquipmentSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        if (store.hasCoordinates)
          StoreMap(
            latitude: store.latitude!,
            longitude: store.longitude!,
            storeName: store.name,
            address: storeAddressLine(store),
          )
        else
          StoreMapFallback(address: storeAddressLine(store)),
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
