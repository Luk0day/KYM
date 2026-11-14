import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static const double radius = 14;
  static const double buttonHeight = 48;
  static const double fieldHeight = 52;

  static const RoundedRectangleBorder _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
  );

  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      error: AppColors.accent,
      onError: Colors.white,
      errorContainer: AppColors.overdueBg,
      onErrorContainer: AppColors.textPrimary,
      outline: AppColors.border,
      outlineVariant: AppColors.inactive,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: _textTheme,
      inputDecorationTheme: _inputDecorationTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTextStyles.screenTitle,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 15,
          color: Colors.white,
        ),
        shape: _buttonShape,
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displaySmall: AppTextStyles.highlightNumber,
    titleLarge: AppTextStyles.screenTitle,
    titleMedium: AppTextStyles.sectionTitle,
    titleSmall: AppTextStyles.cardTitle,
    bodyLarge: AppTextStyles.body,
    bodyMedium: AppTextStyles.body,
    bodySmall: AppTextStyles.metadata,
    labelLarge: AppTextStyles.button,
    labelSmall: AppTextStyles.label,
  );

  static OutlineInputBorder _fieldBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(radius)),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    constraints: const BoxConstraints(minHeight: fieldHeight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
    errorStyle: AppTextStyles.metadata.copyWith(color: AppColors.accent),
    suffixIconColor: AppColors.textSecondary,
    border: _fieldBorder(AppColors.border),
    enabledBorder: _fieldBorder(AppColors.border),
    disabledBorder: _fieldBorder(AppColors.border),
    focusedBorder: _fieldBorder(AppColors.primary, 1.5),
    errorBorder: _fieldBorder(AppColors.accent),
    focusedErrorBorder: _fieldBorder(AppColors.accent, 1.5),
  );

  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.6),
      disabledForegroundColor: Colors.white,
      minimumSize: const Size.fromHeight(buttonHeight),
      elevation: 0,
      shape: _buttonShape,
      textStyle: AppTextStyles.button,
    ),
  );

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.primary,
      minimumSize: const Size.fromHeight(buttonHeight),
      side: const BorderSide(color: AppColors.primary),
      shape: _buttonShape,
      textStyle: AppTextStyles.buttonSecondary,
    ),
  );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: AppTextStyles.fieldLabel,
    ),
  );
}
