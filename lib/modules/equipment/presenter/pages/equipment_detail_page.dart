import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_back_link.dart';
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

/// Tela 6 (Figma): voltar, nome com status, cartão de dados, histórico em
/// linha do tempo e ações por perfil. Aberta pela lista da loja (B27) ou pela
/// leitura do QR do equipamento (B32).
class EquipmentDetailPage extends StatefulWidget {
  const EquipmentDetailPage({
    super.key,
    required this.equipmentId,
    required this.controller,
    required this.role,
    required this.onBack,
    this.currentUserId,
    this.clock = DateTime.now,
  });

  final String equipmentId;
  final EquipmentDetailController controller;
  final UserRole role;
  final String? currentUserId;
  final VoidCallback onBack;

  /// Relógio injetável, para "Hoje" e "Amanhã" nos testes.
  final DateTime Function() clock;

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
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final detail = widget.controller.detail;
            final ready =
                widget.controller.status == EquipmentDetailStatus.ready &&
                detail != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 20, 0),
                  child: KymBackLink(
                    label: ready ? (detail.store?.name ?? 'Voltar') : 'Voltar',
                    onPressed: widget.onBack,
                  ),
                ),
                if (ready) _Header(detail: detail),
                Expanded(child: _body(detail)),
                if (ready)
                  _Actions(
                    detail: detail,
                    role: widget.role,
                    currentUserId: widget.currentUserId,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(EquipmentDetail? detail) => switch (widget.controller.status) {
    EquipmentDetailStatus.loading => const Center(
      child: CircularProgressIndicator(
        semanticsLabel: 'Carregando equipamento',
      ),
    ),
    EquipmentDetailStatus.notFound => _Message(
      text: equipmentNotFoundMessage,
      action: KymButton(label: 'Fechar', onPressed: widget.onBack),
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
      detail: detail!,
      now: widget.clock(),
    ),
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final EquipmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final e = detail.equipment;
    final serial = e.serialNumber?.trim();
    final subtitle = [
      detail.store?.name,
      if (serial != null && serial.isNotEmpty) 'Série $serial',
    ].whereType<String>().join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(e.name, style: AppTextStyles.screenTitle),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: EquipmentStatusChip(status: e.status),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.metadata),
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
    required this.controller,
    required this.detail,
    required this.now,
  });

  final EquipmentDetailController controller;
  final EquipmentDetail detail;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final history = controller.showAllHistory
        ? detail.history
        : detail.recentHistory;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      children: [
        _InfoCard(detail: detail, now: now),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  'Histórico de manutenção',
                  style: AppTextStyles.sectionTitle,
                ),
              ),
            ),
            Text(
              detail.history.length == 1
                  ? '1 registro'
                  : '${detail.history.length} registros',
              style: AppTextStyles.metadata,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          Text(
            'Nenhuma manutenção registrada para este equipamento.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          )
        else
          for (var i = 0; i < history.length; i++)
            _TimelineItem(order: history[i], isLast: i == history.length - 1),
        if (detail.hasMoreHistory) ...[
          const SizedBox(height: 8),
          KymButton(
            label: controller.showAllHistory
                ? 'Ver menos'
                : 'Ver todas (${detail.history.length})',
            variant: KymButtonVariant.soft,
            onPressed: controller.toggleHistory,
          ),
        ],
      ],
    );
  }
}

/// Cartão de dados em duas colunas; campos vazios somem.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.detail, required this.now});

  final EquipmentDetail detail;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final e = detail.equipment;
    final next = detail.nextPreventive;
    final cells = <_Cell>[
      _Cell('Modelo', e.model),
      _Cell('Nº de série', e.serialNumber),
      _Cell(
        'Instalado em',
        e.installedAt == null ? null : formatDate(e.installedAt!),
      ),
      _Cell(
        'Próxima preventiva',
        next == null ? null : formatWhen(next, now),
        highlight: true,
      ),
      _Cell('Categoria', e.category),
      _Cell('Marca', e.brand),
      _Cell('Observações', e.notes, fullWidth: true),
    ].where((c) => c.value != null && c.value!.trim().isNotEmpty).toList();

    if (cells.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 16.0;
          final half = (box.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: 14,
            children: [
              for (final c in cells)
                SizedBox(
                  width: c.fullWidth ? box.maxWidth : half,
                  child: c.build(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Cell {
  const _Cell(
    this.label,
    this.value, {
    this.highlight = false,
    this.fullWidth = false,
  });

  final String label;
  final String? value;
  final bool highlight;
  final bool fullWidth;

  Widget build() => Semantics(
    container: true,
    label: '$label: $value',
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.label),
        const SizedBox(height: 2),
        Text(
          value!,
          style: AppTextStyles.cardTitle.copyWith(
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.order, required this.isLast});

  final MaintenanceOrder order;
  final bool isLast;

  bool get _corrective => order.type == OrderType.corretiva;

  (String, KymChipTone)? get _statusChip => switch (order.status) {
    OrderStatus.concluida => null,
    OrderStatus.aberta => ('Aberta', KymChipTone.pending),
    OrderStatus.agendada => ('Agendada', KymChipTone.pending),
    OrderStatus.emAndamento => ('Em andamento', KymChipTone.pending),
    OrderStatus.cancelada => ('Cancelada', KymChipTone.neutral),
  };

  @override
  Widget build(BuildContext context) {
    final date = formatDate(EquipmentDetail.orderDate(order));
    final description = order.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    // O nome do técnico não existe no banco local (RLS); só o papel.
    final technician = order.assignedTo != null;
    final status = _statusChip;
    final dotColor = _corrective ? AppColors.accent : AppColors.primary;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [
        orderTypeLabel(order.type),
        if (status != null) status.$1,
        date,
        if (technician) 'Técnico',
        if (hasDescription) description,
      ].join(', '),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bg,
                      border: Border.all(color: dotColor, width: 3),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: AppColors.border),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(date, style: AppTextStyles.cardTitle),
                          ),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (status != null)
                                KymChip(label: status.$1, tone: status.$2),
                              KymChip(
                                label: orderTypeLabel(order.type),
                                tone: _corrective
                                    ? KymChipTone.overdue
                                    : KymChipTone.pending,
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (technician) ...[
                        const SizedBox(height: 4),
                        const Text('Técnico', style: AppTextStyles.metadata),
                      ],
                      if (hasDescription) ...[
                        const SizedBox(height: 4),
                        Text(description, style: AppTextStyles.body),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ações por perfil (B15), fixas no rodapé como no Figma. Ficam desabilitadas
/// até as telas de destino existirem: B34 (chamado), B36 (registro), B29
/// (edição) e B47 (QR Code).
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
        const KymButton(
          label: 'Abrir chamado corretivo',
          leading: Icon(Icons.error_outline, size: 20),
          onPressed: null,
        ),
      // TODO(B36): registrar a manutenção da ordem atribuída ao técnico.
      if (role.canRegisterMaintenance &&
          userId != null &&
          detail.hasOpenOrderAssignedTo(userId))
        const KymButton(
          label: 'Registrar manutenção',
          leading: Icon(Icons.assignment_turned_in_outlined, size: 20),
          onPressed: null,
        ),
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
          label: 'Ver QR Code do equipamento',
          variant: KymButtonVariant.secondary,
          leading: Icon(Icons.qr_code_2, size: 20),
          onPressed: null,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            buttons[i],
          ],
        ],
      ),
    );
  }
}
