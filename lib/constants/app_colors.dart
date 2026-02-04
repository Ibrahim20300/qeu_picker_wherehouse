import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // الألوان الأساسية
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryLight = Color(0xFF1E88E5);
  static const Color primaryDark = Color(0xFF0D47A1);

  // ألوان الحالات
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFD32F2F);
  static const Color pending = Color(0xFFEF6C00);

  // ألوان محايدة
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE0E0E0);

  // ألوان بشفافية
  static Color primaryWithOpacity(double opacity) =>
      primary.withValues(alpha: opacity);
  static Color successWithOpacity(double opacity) =>
      success.withValues(alpha: opacity);
  static Color warningWithOpacity(double opacity) =>
      warning.withValues(alpha: opacity);
  static Color errorWithOpacity(double opacity) =>
      error.withValues(alpha: opacity);
  static Color pendingWithOpacity(double opacity) =>
      pending.withValues(alpha: opacity);
}
