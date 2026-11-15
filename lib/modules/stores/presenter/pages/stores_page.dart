import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_banner.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../../../../shared/presenter/widgets/kym_text_field.dart';
import '../../domain/entities/store_summary.dart';
import '../controllers/stores_controller.dart';
import '../utils/stores_messages.dart';
import '../widgets/store_filter_sheet.dart';
import '../widgets/store_tile.dart';

class StoresPage extends StatefulWidget {
  const StoresPage({
    super.key,
    required this.controller,
    required this.onStoreSelected,
  });

  final StoresController controller;
  final ValueChanged<StoreSummary> onStoreSelected;

  @override
  State<StoresPage> createState() => _StoresPageState();
}

class _StoresPageState extends State<StoresPage> {
  final _searchController = TextEditingController();

  StoresController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final ok = await _controller.refresh();
    if (!ok && mounted) {
      final message = _controller.syncMessage;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Future<void> _openFilters() async {
    final result = await showStoreFilterSheet(
      context,
      filter: _controller.filter,
      cities: _controller.result.availableCities,
    );
    if (result != null) {
      _controller.applyFilters(
        city: result.city,
        onlyWithPending: result.onlyWithPending,
      );
    }
  }

  void _clearAll() {
    _searchController.clear();
    _controller.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lojas')),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasFilters = _controller.filter.hasSheetFilters;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: KymTextField(
              label: 'Buscar loja',
              hintText: 'Nome, código ou cidade',
              controller: _searchController,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onChanged: _controller.setQuery,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: hasFilters ? 'Filtros (ativos)' : 'Filtros',
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: hasFilters,
              smallSize: 8,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_controller.status) {
      case StoresStatus.loading:
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Carregando lojas'),
        );
      case StoresStatus.error:
        return _buildError();
      case StoresStatus.ready:
        return _buildList();
    }
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KymBanner(message: storesLoadErrorMessage),
          const SizedBox(height: 16),
          KymButton(label: 'Tentar novamente', onPressed: _controller.retry),
        ],
      ),
    );
  }

  Widget _buildList() {
    final result = _controller.result;

    Widget child;
    if (result.totalVisible == 0) {
      child = const _EmptyState(
        title: 'Nenhuma loja atribuída a você',
        message: 'Quando uma loja for atribuída, ela aparece aqui.',
      );
    } else if (result.items.isEmpty) {
      child = _EmptyState(
        title: 'Nenhuma loja encontrada',
        message: 'Tente outro termo ou limpe os filtros.',
        actionLabel: 'Limpar busca e filtros',
        onAction: _clearAll,
      );
    } else {
      child = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        itemCount: result.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final store = result.items[index];
          return StoreTile(
            store: store,
            onTap: () => widget.onStoreSelected(store),
          );
        },
      );
    }

    return RefreshIndicator(onRefresh: _refresh, child: child);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 48, 22, 24),
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.storefront_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle,
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          KymButton(
            label: actionLabel!,
            variant: KymButtonVariant.secondary,
            onPressed: onAction,
          ),
        ],
      ],
    );
  }
}
