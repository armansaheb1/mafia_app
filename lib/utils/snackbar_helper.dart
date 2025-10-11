import 'package:flutter/material.dart';

class SnackBarHelper {
  static void showSnackBar(
    BuildContext context, 
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 3),
    Color? textColor,
    SnackBarAction? action,
  }) {
    // حذف SnackBar قبلی اگر وجود دارد
    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: 14,
          ),
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF2C2C2C),
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating, // شناور بودن
        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 100, // فاصله از پایين صفحه
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 8,
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: const Color(0xFF4CAF50),
      duration: const Duration(seconds: 2),
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: const Color(0xFF8B0000),
      duration: const Duration(seconds: 4),
    );
  }

  static void showWarningSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: const Color(0xFFFF9800),
      textColor: Colors.black,
      duration: const Duration(seconds: 3),
    );
  }

  static void showInfoSnackBar(BuildContext context, String message) {
    showSnackBar(
      context,
      message,
      backgroundColor: const Color(0xFF2196F3),
      duration: const Duration(seconds: 2),
    );
  }

  static void clearSnackBars(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }
}
