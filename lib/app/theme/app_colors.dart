import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color bg = Color(0xFFFFFDF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8E3D5);
  static const Color textPrimary = Color(0xFF1F2140);
  static const Color textSecondary = Color(0xFF6E7191);
  static const Color inactive = Color(0xFFE6E1D3);

  static const Color primary = Color(0xFF5B5BD6);
  static const Color accent = Color(0xFFF2664D);

  static const Color pendingBg = Color(0xFFDBEAFB);
  static const Color pendingFg = primary;
  static const Color overdueBg = Color(0xFFFFE3D9);
  static const Color overdueFg = accent;
  static const Color doneBg = Color(0xFFD5F0E3);
  static const Color doneFg = Color(0xFF2E8B6A);
  static const Color equipmentTileBg = Color(0xFFE6DFF9);

  static const Color darkBg = Color(0xFF1C1F36);
  static const Color darkPanel = Color(0xFF363A50);
  static const Color scanFrame = Color(0xFFFFE066);
  static const Color scanLine = accent;
  static const Color darkText = Color(0xFFFFFFFF);
}
