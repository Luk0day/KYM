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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'KYM',
                style: AppTextStyles.highlightNumber.copyWith(
                  color: AppColors.primary,
                  letterSpacing: -0.85,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
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
