import 'package:flutter/material.dart';

/// Helper class للتعامل مع السناك بار
class SnackbarHelper {
  /// عرض سناك بار موحد
  static void show(
    BuildContext context,
    String message, {
    Color backgroundColor = Colors.green,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
    bool floating = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: icon != null
            ? Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message)),
                ],
              )
            : Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: floating ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
        margin: floating ? const EdgeInsets.all(16) : null,
      ),
    );
  }

  /// سناك بار نجاح
  static void success(BuildContext context, String message, {bool floating = false}) {
    show(context, message, backgroundColor: Colors.green, icon: Icons.check_circle, floating: floating);
  }

  /// سناك بار خطأ
  static void error(BuildContext context, String message, {bool floating = false}) {
    show(context, message, backgroundColor: Colors.red, icon: Icons.warning, floating: floating);
  }

  /// سناك بار معلومات
  static void info(BuildContext context, String message, {bool floating = false}) {
    show(context, message, backgroundColor: Colors.blue, icon: Icons.info, floating: floating);
  }
}
