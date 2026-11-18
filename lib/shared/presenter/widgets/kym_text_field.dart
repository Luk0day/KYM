import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

class KymTextField extends StatelessWidget {
  const KymTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.autocorrect = true,
    this.enabled = true,
    this.suffixIcon,
    this.prefixIcon,
    this.hideLabel = false,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool autocorrect;
  final bool enabled;
  final Widget? suffixIcon;
  final Widget? prefixIcon;

  /// Esconde o rótulo visual (o campo de busca só tem o placeholder).
  final bool hideLabel;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideLabel) ...[
          Text(label, style: AppTextStyles.fieldLabel),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          autocorrect: autocorrect,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            // Sem rótulo visual, o placeholder é o que o leitor de tela anuncia.
            hintText: hintText ?? (hideLabel ? label : null),
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}
