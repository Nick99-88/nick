import 'package:flutter/material.dart';

/// 🏛️ Show a permission dialog with customizable title, message, and action
Future<void> showPermissionDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String actionText,
  required Color actionColor,
  required VoidCallback onAction,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text(actionText),
            style: TextButton.styleFrom(foregroundColor: actionColor),
            onPressed: () {
              onAction();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}