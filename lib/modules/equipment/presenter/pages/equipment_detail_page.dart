import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_banner.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../../../../shared/presenter/widgets/kym_chip.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/domain/entities/user_role_permissions.dart';
import '../../../orders/domain/entities/maintenance_order.dart';
import '../../domain/entities/equipment_detail.dart';
import '../controllers/equipment_detail_controller.dart';
import '../utils/equipment_messages.dart';
import '../widgets/equipment_status_chip.dart';

const String equipmentNotFoundMessage =
    'Equipamento não encontrado. Ele pode ter sido removido ou não estar mais atribuído a você.';
const String equipmentDetailErrorMessage =
    'Não foi possível carregar o equipamento. Tente novamente.';

/// Tela 6: dados, status e histórico de manutenções do equipamento. Aberta
/// pela lista da loja (B27) ou pela leitura do QR do equipamento (B32).
class EquipmentDetailPage extends StatefulWidget {
  const EquipmentDetailPage({
    super.key,
    required this.equipmentId,
    required this.controller,
    required this.role,
    required this.onBack,
    this.currentUserId,
  });

  final String equipmentId;
  final EquipmentDetailController controller;
  final UserRole role;
  final String? currentUserId;
  final VoidCallback onBack;

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.equipmentId);
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
          child: const Text('Equipamento', style: AppTextStyles.sectionTitle),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => switch (widget.controller.status) {
            EquipmentDetailStatus.loading => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando equipamento',
              ),
            ),
            EquipmentDetailStatus.notFound => _Message(
              text: equipmentNotFoundMessage,
              action: KymButton(label: 'Voltar', onPressed: widget.onBack),
            ),
            EquipmentDetailStatus.error => _Message(
              text: equipmentDetailErrorMessage,
              isError: true,
              action: KymButton(
                label: 'Tentar novamente',
                onPressed: widget.controller.retry,
              ),
            ),
            EquipmentDetailStatus.ready => _Content(
              controller: widget.controller,
              detail: widget.controller.detail!,
              role: widget.role,
              currentUserId: widget.currentUserId,
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
    required this.controller,
    required this.detail,
    required this.role,
    required this.currentUserId,
  });

  final EquipmentDetailController controller;
  final EquipmentDetail detail;
  final UserRole role;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final e = detail.equipment;
    final rows = <(String, String?)>[
      ('Loja', detail.store?.name),
      ('Categoria', e.category),
      ('Marca', e.brand),
      ('Modelo', e.model),
      ('Nº de série', e.serialNumber),
      (
        'Instalado em',
        e.installedAt == null ? null : formatDate(e.installedAt!),
      ),
      ('Observações', e.notes),
    ].where((r) => r.$2 != null && r.$2!.trim().isNotEmpty).toList();

    final history = controller.showAllHistory
        ? detail.history
        : detail.recentHistory;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(e.name, style: AppTextStyles.screenTitle),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: EquipmentStatusChip(status: e.status),
        ),
        const SizedBox(height: 16),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              container: true,
              label: '$label: $value',
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(label, style: AppTextStyles.metadata),
                    ),
                    Expanded(child: Text(value!, style: AppTextStyles.body)),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _Actions(detail: detail, role: role, currentUserId: currentUserId),
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: const Text(
            'Histórico de manutenções',
            style: AppTextStyles.sectionTitle,
          ),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          Text(
            'Nenhuma manutenção registrada para este equipamento.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          )
        else
          for (final order in history) _HistoryTile(order: order),
        if (detail.hasMoreHistory)
          KymButton(
            label: controller.showAllHistory
                ? 'Ver menos'
                : 'Ver todas (${detail.history.length})',
            variant: KymButtonVariant.soft,
            onPressed: controller.toggleHistory,
          ),
      ],
    );
  }
}

/// Ações por perfil (B15). Ficam desabilitadas até as telas de destino
/// existirem: B34 (chamado), B36 (registro), B29 (edição) e B47 (QR Code).
class _Actions extends StatelessWidget {
  const _Actions({
    required this.detail,
    required this.role,
    required this.currentUserId,
  });

  final EquipmentDetail detail;
  final UserRole role;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final userId = currentUserId;
    final buttons = <Widget>[
      // TODO(B34): abrir o chamado corretivo.
      if (role.canOpenCorrective)
        const KymButton(label: 'Abrir chamado', onPressed: null),
      // TODO(B36): registrar a manutenção da ordem atribuída ao técnico.
      if (role.canRegisterMaintenance &&
          userId != null &&
          detail.hasOpenOrderAssignedTo(userId))
        const KymButton(label: 'Registrar manutenção', onPressed: null),
      // TODO(B29): editar o equipamento.
      if (role.canEditEquipment)
        const KymButton(
          label: 'Editar',
          variant: KymButtonVariant.soft,
          onPressed: null,
        ),
      // TODO(B47): mostrar o QR Code do equipamento.
      if (role.canManageQrCodes)
        const KymButton(
          label: 'Ver QR Code',
          variant: KymButtonVariant.soft,
          onPressed: null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in buttons) ...[b, const SizedBox(height: 10)],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.order});

  final MaintenanceOrder order;

  String get _type =>
      order.type == OrderType.preventiva ? 'Preventiva' : 'Corretiva';

  (String, KymChipTone) get _status => switch (order.status) {
    OrderStatus.aberta => ('Aberta', KymChipTone.pending),
    OrderStatus.agendada => ('Agendada', KymChipTone.pending),
    OrderStatus.emAndamento => ('Em andamento', KymChipTone.pending),
    OrderStatus.concluida => ('Concluída', KymChipTone.done),
    OrderStatus.cancelada => ('Cancelada', KymChipTone.neutral),
  };

  @override
  Widget build(BuildContext context) {
    final (statusLabel, tone) = _status;
    final date = formatDate(EquipmentDetail.orderDate(order));
    final description = order.description?.trim();
    // Nome do técnico não existe no banco local (RLS); mostra só o papel.
    final technician = order.assignedTo != null ? 'Técnico' : null;
    final summary = [date, ?technician].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        container: true,
        label:
            '$_type, $statusLabel, $summary'
            '${description == null || description.isEmpty ? '' : '. $description'}',
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_type, style: AppTextStyles.cardTitle),
                      Text(summary, style: AppTextStyles.metadata),
                      if (description != null && description.isNotEmpty)
                        Text(description, style: AppTextStyles.body),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                KymChip(label: statusLabel, tone: tone),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
