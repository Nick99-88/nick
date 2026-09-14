// lib/core/platform_gate.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class PlatformGate {
  static Future<String> getDeviceId() async {
    if (kIsWeb) return "CHROME-MOCK-ID-999";

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      // This maps to 'device_id' in your sync_identity payload
      return androidInfo.id;
    }
    return "UNKNOWN-PLATFORM";
  }

  static Future<String> getDeviceName() async {
    if (kIsWeb) return "Web Browser";

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return "${androidInfo.brand[0].toUpperCase()}${androidInfo.brand.substring(1)} ${androidInfo.model}";
    }
    return "Unknown Device";
  }
}