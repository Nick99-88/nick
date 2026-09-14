import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'task_service.dart';

class WidgetUpdateService {
  static Timer? _timer;
  static int _tick = 0;

  static void start() {
    _timer?.cancel();
    if (Platform.isAndroid) {
      TaskService.updateWidgetWithNextTask();
    }
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static bool get isRunning => _timer != null;
}
