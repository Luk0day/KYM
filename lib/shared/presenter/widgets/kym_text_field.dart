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
    final placeholder = hintText ?? (hideLabel ? label : null);

    final field = TextFormField(
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
        hintText: hideLabel ? null : placeholder,
        // Sem rótulo visual, o nome vem do Semantics abaixo; o placeholder fica
        // fora da acessibilidade para não ser lido duas vezes.
        hint: hideLabel && placeholder != null
            ? ExcludeSemantics(
                child: Text(
                  placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).inputDecorationTheme.hintStyle,
                ),
              )
            : null,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      ),
    );

    if (hideLabel) {
      // O placeholder some da acessibilidade quando o campo tem texto; o
      // rótulo fundido ao campo mantém o nome para o leitor de tela.
      return MergeSemantics(
        child: Semantics(label: label, child: field),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 6),
        field,
      ],
    );
  }
}
