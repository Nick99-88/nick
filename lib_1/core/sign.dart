import 'package:flutter/material.dart';

class StarlightUtils {

  /// 🏛️ The Main Sign Box Engine
  /// Displays a colored notification box (Green for success, Red for error)
  static void showSignBox(BuildContext context, String message, Color color) {
    // Remove any existing boxes first to avoid stacking blunders
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 🟢 Success Definition
  static void showSuccessBox(BuildContext context, String message) {
    showSignBox(context, message, Colors.green);
  }

  /// 🔴 Error Definition
  static void showErrorBox(BuildContext context, String message) {
    showSignBox(context, message, Colors.red);
  }

  /// 🟠 Warning Definition (For Offline States)
  static void showWarningBox(BuildContext context, String message) {
    showSignBox(context, message, Colors.orange);
  }
  static void showOfflineWarning(BuildContext context, String message) {
    showSignBox(context, message, Colors.orange);
  }
}