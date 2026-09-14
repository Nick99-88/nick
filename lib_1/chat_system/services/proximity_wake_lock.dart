import 'package:flutter/services.dart';

class ProximityWakeLock {
  static const _channel = MethodChannel('com.starlight.console/proximity');
  static bool _acquired = false;

  static Future<void> acquire() async {
    if (!_acquired) {
      await _channel.invokeMethod('acquireProximityWakeLock');
      _acquired = true;
    }
  }

  static Future<void> release() async {
    if (_acquired) {
      await _channel.invokeMethod('releaseProximityWakeLock');
      _acquired = false;
    }
  }

  static bool get isAcquired => _acquired;
}