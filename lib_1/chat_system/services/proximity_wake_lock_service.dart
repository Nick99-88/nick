import 'package:flutter/services.dart';

class ProximityWakeLockService {
  static const MethodChannel _channel = MethodChannel('com.starlight.console/proximity');

  static Future<void> acquire() async {
    try {
      await _channel.invokeMethod('acquireProximityWakeLock');
    } on PlatformException catch (e) {
      print('📞 ProximityWakeLock: Failed to acquire - ${e.message}');
    }
  }

  static Future<void> release() async {
    try {
      await _channel.invokeMethod('releaseProximityWakeLock');
    } on PlatformException catch (e) {
      print('📞 ProximityWakeLock: Failed to release - ${e.message}');
    }
  }
}