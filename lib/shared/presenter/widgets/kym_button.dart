import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

enum KymButtonVariant { primary, secondary, tertiary, destructive }

class KymButton extends StatelessWidget {
  const KymButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = KymButtonVariant.primary,
    this.isLoading = false,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final KymButtonVariant variant;
  final bool isLoading;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final callback = isLoading ? null : onPressed;
    final child = isLoading ? _buildSpinner() : _buildContent();

    switch (variant) {
      case KymButtonVariant.primary:
        return FilledButton(onPressed: callback, child: child);
      case KymButtonVariant.secondary:
        return OutlinedButton(onPressed: callback, child: child);
      case KymButtonVariant.tertiary:
        return TextButton(onPressed: callback, child: child);
      case KymButtonVariant.destructive:
        return OutlinedButton(
          onPressed: callback,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
          child: child,
        );
    }
  }

  Widget _buildContent() {
    if (leading == null) {
      return Text(label, textAlign: TextAlign.center);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading!,
        const SizedBox(width: 10),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }

  Widget _buildSpinner() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: _spinnerColor,
      ),
    );
  }

  Color get _spinnerColor {
    switch (variant) {
      case KymButtonVariant.primary:
        return Colors.white;
      case KymButtonVariant.destructive:
        return AppColors.accent;
      case KymButtonVariant.secondary:
      case KymButtonVariant.tertiary:
        return AppColors.primary;
    }
  }
}
