import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/theme/app_colors.dart';
import 'package:kym/app/theme/app_text_styles.dart';
import 'package:kym/app/theme/app_theme.dart';

void main() {
  final theme = AppTheme.light;

  test('usa o fundo creme e as cores de marca do DESIGN.md', () {
    expect(theme.scaffoldBackgroundColor, AppColors.bg);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.secondary, AppColors.accent);
    expect(theme.colorScheme.onSurface, AppColors.textPrimary);
  });

  test('usa Lato e a escala tipográfica', () {
    expect(theme.textTheme.bodyMedium?.fontFamily, AppTextStyles.fontFamily);
    expect(theme.textTheme.titleLarge?.fontSize, 22);
    expect(theme.textTheme.titleMedium?.fontSize, 17);
    expect(theme.textTheme.bodyMedium?.fontSize, 15);
    expect(theme.textTheme.bodySmall?.fontSize, 13);
    expect(theme.textTheme.labelSmall?.fontSize, 11);
  });

  test('botão principal é coral', () {
    final style = theme.filledButtonTheme.style!;

    expect(style.backgroundColor?.resolve({}), AppColors.accent);
  });

  test('campo de texto muda a borda no foco e no erro', () {
    final input = theme.inputDecorationTheme;

    expect((input.enabledBorder as OutlineInputBorder).borderSide.color,
        AppColors.border);
    expect((input.focusedBorder as OutlineInputBorder).borderSide.color,
        AppColors.primary);
    expect((input.errorBorder as OutlineInputBorder).borderSide.color,
        AppColors.accent);
  });
}
