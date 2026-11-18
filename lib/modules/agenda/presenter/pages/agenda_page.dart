import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularStateX;

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../../domain/entities/agenda_filter.dart';
import '../controllers/agenda_controller.dart';
import '../utils/agenda_dates.dart';
import '../widgets/agenda_cards.dart';
import '../widgets/agenda_filters.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late final AgendaController _controller;

  static const _situations = [
    AgendaChipOption(AgendaSituationFilter.todas, 'Todas'),
    AgendaChipOption(AgendaSituationFilter.pendentes, 'Pendentes'),
    AgendaChipOption(AgendaSituationFilter.atrasadas, 'Atrasadas'),
    AgendaChipOption(AgendaSituationFilter.concluidas, 'Concluídas'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = context.read<AgendaController>()..start();
  }

  Future<void> _pickRange() async {
    final filter = _controller.filter;
    final today = _controller.today;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: filter.start, end: filter.end),
      helpText: 'Escolha o período',
      saveText: 'Aplicar',
    );
    if (range != null) {
      _controller.selectRange(range.start, range.end);
    }
  }

  void _onPeriod(AgendaPeriod period) {
    if (period == AgendaPeriod.personalizado) {
      _pickRange();
    } else {
      _controller.selectPeriod(period);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [..._buildTop(), ..._buildBody()],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTop() {
    final filter = _controller.filter;
    final user = _controller.user;
    final name = user.displayName ?? user.email;
    final personalized = filter.period == AgendaPeriod.personalizado;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: const Text('Agenda', style: AppTextStyles.screenTitle),
            ),
            const SizedBox(height: 2),
            Text(
              AgendaDates.monthYear(filter.start),
              style: AppTextStyles.metadata,
            ),
            const SizedBox(height: 16),
            AgendaGreetingCard(name: name, summary: _controller.summary),
          ],
        ),
      ),
      AgendaDayStrip(
        days: _controller.stripDays,
        selected: filter.start,
        today: _controller.today,
        onSelected: _controller.selectDay,
      ),
      const SizedBox(height: 4),
      AgendaChipRow<AgendaSituationFilter>(
        semanticsLabel: 'Filtrar por situação',
        options: _situations,
        selected: filter.situation,
        onSelected: _controller.selectSituation,
      ),
      AgendaChipRow<AgendaPeriod>(
        semanticsLabel: 'Filtrar por período',
        options: [
          const AgendaChipOption(AgendaPeriod.hoje, 'Hoje'),
          const AgendaChipOption(AgendaPeriod.seteDias, '7 dias'),
          const AgendaChipOption(AgendaPeriod.trintaDias, '30 dias'),
          AgendaChipOption(
            AgendaPeriod.personalizado,
            personalized
                ? '${AgendaDates.dayMonth(filter.start)} – '
                      '${AgendaDates.dayMonth(filter.end)}'
                : 'Personalizado',
          ),
        ],
        selected: filter.period,
        onSelected: _onPeriod,
      ),
    ];
  }

  List<Widget> _buildBody() {
    switch (_controller.status) {
      case AgendaStatus.loading:
        return const [
          Padding(
            padding: EdgeInsets.all(48),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando a agenda',
              ),
            ),
          ),
        ];
      case AgendaStatus.error:
        return [
          _Message(
            icon: Icons.cloud_off_outlined,
            text: 'Não foi possível carregar a agenda.',
            action: KymButton(
              label: 'Tentar novamente',
              variant: KymButtonVariant.secondary,
              onPressed: _controller.start,
            ),
          ),
        ];
      case AgendaStatus.ready:
        final sections = _controller.sections;
        if (sections.isEmpty) {
          return [
            _Message(
              icon: Icons.event_available_outlined,
              text: _emptyText(_controller.filter.situation),
            ),
          ];
        }
        final today = _controller.today;
        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final section in sections) ...[
                  AgendaSectionHeader(section: section, today: today),
                  for (final item in section.items)
                    AgendaOrderCard(item: item, today: today),
                ],
              ],
            ),
          ),
        ];
    }
  }

  static String _emptyText(
    AgendaSituationFilter situation,
  ) => switch (situation) {
    AgendaSituationFilter.todas => 'Nenhuma visita no período.',
    AgendaSituationFilter.pendentes => 'Nenhuma visita pendente no período.',
    AgendaSituationFilter.atrasadas => 'Nenhuma visita atrasada. Tudo em dia!',
    AgendaSituationFilter.concluidas => 'Nenhuma visita concluída no período.',
  };
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
