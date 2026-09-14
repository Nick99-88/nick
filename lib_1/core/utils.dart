import 'package:flutter/material.dart';
import 'theme.dart';

class StarlightUtils {

  // Add this to your core/utils.dart
  static void showStatusBox(BuildContext context, String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSuccess ? StarlightTheme.accentGreen : StarlightTheme.errorRed,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Row(
            children: [
              Icon(isSuccess ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // 🏛️ Professional "Success" Sign Box
  static void showSuccessBox(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StarlightTheme.accentGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🏛️ Professional "Error" Sign Box
  static void showErrorBox(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StarlightTheme.errorRed,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🏛️ Professional "Info" Sign Box
  static void showInfoBox(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: StarlightTheme.primaryBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
