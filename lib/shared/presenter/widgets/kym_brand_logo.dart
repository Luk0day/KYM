import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class KymBrandLogo extends StatelessWidget {
  const KymBrandLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'KYM, Know Your Maintenance',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'KYM',
                style: AppTextStyles.highlightNumber.copyWith(
                  color: AppColors.primary,
                  letterSpacing: -0.85,
                ),
              ),
              const SizedBox(width: 4),
              // Alinhamento por baseline quebra o cálculo de altura da tela de
              // login (DecoratedBox não calcula baseline). O 11 é o descendente
              // da Lato em 34sp (~7) somado aos 4 de elevação do mock.
              const Padding(
                padding: EdgeInsets.only(bottom: 11),
                child: SizedBox(
                  width: 7,
                  height: 7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Know Your Maintenance',
            style: AppTextStyles.metadata.copyWith(letterSpacing: 0.33),
          ),
        ],
      ),
    );
  }
}
