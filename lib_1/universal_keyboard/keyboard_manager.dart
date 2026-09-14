import 'package:flutter/material.dart';

class UniversalKeyboardManager {
  static final UniversalKeyboardManager _instance = UniversalKeyboardManager._();
  factory UniversalKeyboardManager() => _instance;
  UniversalKeyboardManager._();

  TextEditingController? _activeController;

  void registerController(TextEditingController controller) {
    _activeController = controller;
  }

  void unregisterController(TextEditingController controller) {
    if (_activeController == controller) {
      _activeController = null;
    }
  }

  void insertText(String text) {
    if (_activeController != null) {
      final controller = _activeController!;
      final currentText = controller.text;
      final selection = controller.selection;
      
      final start = selection.baseOffset < 0 ? currentText.length : selection.baseOffset;
      final end = selection.extentOffset < 0 ? currentText.length : selection.extentOffset;
      
      final newText = currentText.replaceRange(start, end, text);
      final newOffset = start + text.length;
      
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
  }

  void deleteBackward() {
    if (_activeController != null) {
      final controller = _activeController!;
      final currentText = controller.text;
      final selection = controller.selection;
      
      final start = selection.baseOffset < 0 ? currentText.length : selection.baseOffset;
      final end = selection.extentOffset < 0 ? currentText.length : selection.extentOffset;
      
      if (start == end) {
        if (start > 0) {
          final newText = currentText.replaceRange(start - 1, start, '');
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: start - 1),
          );
        }
      } else {
        final newText = currentText.replaceRange(start, end, '');
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start),
        );
      }
    }
  }

  void performAction(TextInputAction action) {
    // Handles done/check text actions
  }
}
