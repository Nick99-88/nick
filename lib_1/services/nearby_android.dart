import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android implementation — requests Bluetooth, Location, and Nearby WiFi
/// permissions required for Nearby Connections P2P.
class NearbyPlatform {
  static Future<void> requestPermissions() async {
    debugPrint('🏛️ [NearbyPermissions] ===== START requestPermissions =====');
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('🏛️ [NearbyPermissions] Skipped — platform is ${defaultTargetPlatform.name}');
      return;
    }

    try {
      final permissions = <Permission>[
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices,
      ];

      debugPrint('🏛️ [NearbyPermissions] Requesting ${permissions.length} permissions...');

      final statuses = await permissions.request();

      for (final entry in statuses.entries) {
        final name = entry.key.toString().split('.').last;
        final status = entry.value;
        final granted = status.isGranted;
        debugPrint('🏛️ [NearbyPermissions]   $name => ${status.name} (granted=$granted)');
      }

      final denied = statuses.entries
          .where((e) => !e.value.isGranted && !e.value.isLimited)
          .map((e) => e.key.toString().split('.').last)
          .toList();

      if (denied.isNotEmpty) {
        debugPrint('🏛️ [NearbyPermissions] DENIED: $denied');
      } else {
        debugPrint('🏛️ [NearbyPermissions] ALL GRANTED');
      }

      final locationServiceEnabled = await Permission.locationWhenInUse.serviceStatus.isEnabled;
      debugPrint('🏛️ [NearbyPermissions] Location service enabled: $locationServiceEnabled');

      if (!locationServiceEnabled) {
        debugPrint('🏛️ [NearbyPermissions] Opening app settings to enable location...');
        await openAppSettings();
      }

      debugPrint('🏛️ [NearbyPermissions] ===== END requestPermissions =====');
    } catch (e) {
      debugPrint('🏛️ [NearbyPermissions] ERROR: $e');
    }
  }

  /// Call this from any screen to log current permission state without requesting.
  static Future<void> logCurrentStatus() async {
    debugPrint('🏛️ [NearbyPermissions] ===== Current Permission Status =====');
    final checks = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
      Permission.nearbyWifiDevices,
    ];

    for (final p in checks) {
      final status = await p.status;
      final name = p.toString().split('.').last;
      debugPrint('🏛️ [NearbyPermissions]   $name => ${status.name}');
    }

    final locationService = await Permission.locationWhenInUse.serviceStatus.isEnabled;
    debugPrint('🏛️ [NearbyPermissions]   locationServiceEnabled => $locationService');
    debugPrint('🏛️ [NearbyPermissions] ===== End Status =====');
  }
}
