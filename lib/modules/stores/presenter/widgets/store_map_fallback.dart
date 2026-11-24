import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

const String mapUnavailableMessage = 'Mapa indisponível sem internet';

/// Quadro que ocupa o lugar do mapa: loja sem coordenadas, sem internet ou
/// com o servidor de blocos fora do ar. Sempre mostra o endereço em texto.
class StoreMapFallback extends StatelessWidget {
  const StoreMapFallback({super.key, required this.address});

  final String? address;

  @override
  Widget build(BuildContext context) {
    final text = address ?? 'Endereço não informado';
    return Semantics(
      container: true,
      label: '$mapUnavailableMessage. Endereço: $text',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
                  const Icon(
                    Icons.map_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mapUnavailableMessage,
                      style: AppTextStyles.cardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(text, style: AppTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
