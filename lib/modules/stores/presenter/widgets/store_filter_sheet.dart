import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../../domain/entities/store_filter.dart';

/// Abre o BottomSheet de filtros. Devolve o filtro novo (a busca é mantida) ou
/// `null` se o usuário fechou sem aplicar.
Future<StoreFilter?> showStoreFilterSheet(
  BuildContext context, {
  required StoreFilter filter,
  required List<String> cities,
}) {
  return showModalBottomSheet<StoreFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _StoreFilterSheet(filter: filter, cities: cities),
  );
}

class _StoreFilterSheet extends StatefulWidget {
  const _StoreFilterSheet({required this.filter, required this.cities});

  final StoreFilter filter;
  final List<String> cities;

  @override
  State<_StoreFilterSheet> createState() => _StoreFilterSheetState();
}

class _StoreFilterSheetState extends State<_StoreFilterSheet> {
  late String? _city;
  late bool _onlyWithPending;

  @override
  void initState() {
    super.initState();
    _city = widget.cities.contains(widget.filter.city)
        ? widget.filter.city
        : null;
    _onlyWithPending = widget.filter.onlyWithPending;
  }

  void _apply() {
    Navigator.of(context).pop(
      widget.filter.copyWith(
        city: _city,
        clearCity: _city == null,
        onlyWithPending: _onlyWithPending,
      ),
    );
  }

  void _clear() {
    setState(() {
      _city = null;
      _onlyWithPending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Filtros', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 16),
            const Text('Cidade', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: _city,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas as cidades'),
                ),
                for (final city in widget.cities)
                  DropdownMenuItem<String?>(value: city, child: Text(city)),
              ],
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Só com pendências'),
              value: _onlyWithPending,
              onChanged: (value) => setState(() => _onlyWithPending = value),
            ),
            const SizedBox(height: 12),
            KymButton(label: 'Aplicar', onPressed: _apply),
            const SizedBox(height: 8),
            KymButton(
              label: 'Limpar filtros',
              variant: KymButtonVariant.secondary,
              onPressed: _clear,
            ),
          ],
        ),
      ),
    );
  }
}
