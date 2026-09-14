import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';

/// 🏛️ PhoneActivityTracker — Collects device metrics locally (zero cost)
/// and syncs to server when cloud fallback is enabled.
/// Data is also dumped to parent via Nearby Connections when devices are close.
class PhoneActivityTracker {
  static PhoneActivityTracker? _instance;
  static PhoneActivityTracker get instance => _instance ??= PhoneActivityTracker._();
  PhoneActivityTracker._();

  Timer? _collectionTimer;
  Timer? _syncTimer;
  bool _isCollecting = false;
  bool _cloudSyncEnabled = false;

  static const _keyActivityLog = 'phone_activity_log';
  static const _keyAppUsage = 'phone_app_usage';
  static const _keyBluetooth = 'phone_bluetooth';
  static const _keyNetwork = 'phone_network';
  static const _keyLocation = 'phone_location';
  static const _keySessionLog = 'phone_session_log';
  static const _keyLastSync = 'phone_last_sync';

  /// Start collecting device metrics every 5 minutes
  Future<void> startCollection() async {
    if (_isCollecting) return;
    _isCollecting = true;

    // Initial collection
    await _collectMetrics();

    // Collect every 5 minutes
    _collectionTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _collectMetrics();
    });

    // Sync to server every 30 minutes if cloud sync is enabled
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      if (_cloudSyncEnabled) await _syncToServer();
    });

    debugPrint('PhoneActivityTracker: Collection started');
  }

  /// Stop all timers
  void stopCollection() {
    _collectionTimer?.cancel();
    _syncTimer?.cancel();
    _isCollecting = false;
    debugPrint('PhoneActivityTracker: Collection stopped');
  }

  /// Toggle cloud sync (parent can enable/disable remotely)
  void setCloudSync(bool enabled) {
    _cloudSyncEnabled = enabled;
  }

  /// Collect all device metrics locally into SharedPreferences
  Future<void> _collectMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // 1. Screen time simulation (real implementation uses UsageStats on Android)
      await _collectScreenTime(prefs, now);

      // 2. App usage / inventory
      await _collectAppInventory(prefs, now);

      // 3. Bluetooth devices
      await _collectBluetooth(prefs);

      // 4. Network info
      await _collectNetwork(prefs);

      // 5. Session log (unlock/lock events)
      await _collectSessionLog(prefs, now);

      await prefs.setString(_keyLastSync, now.toIso8601String());
      debugPrint('PhoneActivityTracker: Metrics collected at $now');
    } catch (e) {
      debugPrint('PhoneActivityTracker: Collection error: $e');
    }
  }

  Future<void> _collectScreenTime(SharedPreferences prefs, DateTime now) async {
    // On Android, real implementation uses UsageStatsManager via MethodChannel
    // For now, we simulate with a local counter
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentMinutes = prefs.getInt('screen_time_$todayKey') ?? 0;

    // Increment by 5 (since we collect every 5 minutes)
    await prefs.setInt('screen_time_$todayKey', currentMinutes + 5);

    final screenTime = {
      'total_minutes': currentMinutes + 5,
      'date': todayKey,
      'last_updated': now.toIso8601String(),
    };
    await prefs.setString(_keyActivityLog, jsonEncode(screenTime));
  }

  Future<void> _collectAppInventory(SharedPreferences prefs, DateTime now) async {
    // Real implementation uses MethodChannel to call UsageStatsManager
    // Returns foreground app time per app and launch counts
    final appUsage = [
      {'name': 'Starlight Console', 'minutes': 45, 'launches': 12},
      {'name': 'WhatsApp', 'minutes': 30, 'launches': 8},
      {'name': 'YouTube', 'minutes': 25, 'launches': 3},
      {'name': 'Chrome', 'minutes': 15, 'launches': 5},
      {'name': 'Instagram', 'minutes': 10, 'launches': 4},
    ];

    // Detect newly installed/uninstalled apps
    final previousApps = (jsonDecode(prefs.getString('known_apps') ?? '[]') as List).cast<String>();
    final currentApps = await _getInstalledApps();
    final newlyInstalled = currentApps.where((a) => !previousApps.contains(a)).toList();
    final uninstalled = previousApps.where((a) => !currentApps.contains(a)).toList();

    await prefs.setString('known_apps', jsonEncode(currentApps));
    await prefs.setString(_keyAppUsage, jsonEncode({
      'app_usage': appUsage,
      'installed_apps': newlyInstalled,
      'uninstalled_apps': uninstalled,
      'total_apps': currentApps.length,
      'last_updated': now.toIso861String(),
    }));
  }

  Future<List<String>> _getInstalledApps() async {
    // Real implementation uses MethodChannel to query PackageManager
    // Returns list of installed package names
    return [];
  }

  Future<void> _collectBluetooth(SharedPreferences prefs) async {
    // Real implementation uses flutter_blue_plus to scan connected devices
    final devices = <Map<String, dynamic>>[];
    await prefs.setString(_keyBluetooth, jsonEncode(devices));
  }

  Future<void> _collectNetwork(SharedPreferences prefs) async {
    String networkType = 'unknown';
    String ssid = '';
    String ip = '';

    try {
      // Detect Wi-Fi vs Mobile
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        if (iface.name.contains('wlan') || iface.name.contains('wifi')) {
          networkType = 'Wi-Fi';
        } else if (iface.name.contains('rmnet') || iface.name.contains('mobile')) {
          networkType = 'Mobile Data';
        }
        if (iface.addresses.isNotEmpty) {
          ip = iface.addresses.first.address;
        }
      }
    } catch (_) {}

    await prefs.setString(_keyNetwork, jsonEncode({
      'type': networkType,
      'ssid': ssid,
      'ip': ip,
    }));
  }

  Future<void> _collectSessionLog(SharedPreferences prefs, DateTime now) async {
    final logs = <Map<String, dynamic>>[];
    final raw = prefs.getString(_keySessionLog);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        logs.addAll(List<Map<String, dynamic>>.from(decoded));
      } catch (_) {}
    }

    logs.add({
      'time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'event': 'collect',
      'timestamp': now.toIso861String(),
    });

    // Keep only last 50 entries
    if (logs.length > 50) logs.removeRange(0, logs.length - 50);

    await prefs.setString(_keySessionLog, jsonEncode(logs));
  }

  /// Build full activity payload for Nearby sync or cloud push
  Future<Map<String, dynamic>> buildActivityPayload() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'screen_time': jsonDecode(prefs.getString(_keyActivityLog) ?? '{}'),
      'app_usage': jsonDecode(prefs.getString(_keyAppUsage) ?? '{}'),
      'bluetooth_devices': jsonDecode(prefs.getString(_keyBluetooth) ?? '[]'),
      'network': jsonDecode(prefs.getString(_keyNetwork) ?? '{}'),
      'location': jsonDecode(prefs.getString(_keyLocation) ?? '{}'),
      'sessions': jsonDecode(prefs.getString(_keySessionLog) ?? '[]'),
      'last_synced': prefs.getString(_keyLastSync),
    };
  }

  /// Sync activity to server (cloud fallback)
  Future<void> _syncToServer() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final childId = await StarlightStorage.getUserIdString();
      if (token == null || childId == null) return;

      final payload = await buildActivityPayload();

      await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/child/$childId/phone-activity'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('PhoneActivityTracker: Synced to server');
    } catch (e) {
      debugPrint('PhoneActivityTracker: Server sync failed: $e');
    }
  }

  /// Get raw bytes for Nearby Connections transfer
  Future<List<int>> getNearbyPayload() async {
    final payload = await buildActivityPayload();
    return utf8.encode(jsonEncode(payload));
  }
}
