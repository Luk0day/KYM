import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_banner.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../../../../shared/presenter/widgets/kym_text_field.dart';
import '../../domain/entities/store_summary.dart';
import '../controllers/stores_controller.dart';
import '../utils/stores_messages.dart';
import '../widgets/store_filter_chips.dart';
import '../widgets/store_tile.dart';
import '../widgets/sync_status_pill.dart';

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _clearAll() {
    _searchController.clear();
    _controller.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildSearch(),
              const SizedBox(height: 12),
              StoreFilterChips(
                selected: _controller.filter.kind,
                onSelected: _controller.selectKind,
              ),
              const SizedBox(height: 4),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final ready = _controller.status == StoresStatus.ready;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: const Text('Lojas', style: AppTextStyles.screenTitle),
                ),
                if (ready) ...[
                  const SizedBox(height: 2),
                  Text(
                    storeCountLabel(_controller.result.items.length),
                    style: AppTextStyles.metadata,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: SyncStatusPill(indicator: _controller.syncIndicator)),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: KymTextField(
        label: 'Buscar loja',
        hintText: 'Buscar loja',
        hideLabel: true,
        controller: _searchController,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        prefixIcon: const ExcludeSemantics(
          child: Icon(Icons.search_rounded, color: AppColors.textSecondary),
        ),
        onChanged: _controller.setQuery,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
        message: 'Tente outro termo ou escolha outro filtro.',
        actionLabel: 'Limpar busca e filtros',
        onAction: _clearAll,
      );
    } else {
      child = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
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
