import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/constants.dart';

class AppIdentity {
  final String id;
  final String appId;
  final String appName;
  final bool isActive;
  final bool isDisabled;
  final String createdAt;
  final String updatedAt;
  final String lastAccessed;

  AppIdentity({
    required this.id,
    required this.appId,
    required this.appName,
    required this.isActive,
    this.isDisabled = false,
    required this.createdAt,
    required this.updatedAt,
    required this.lastAccessed,
  });

  factory AppIdentity.fromJson(Map<String, dynamic> json) {
    return AppIdentity(
      id: json['id'].toString(),
      appId: json['app_id'],
      appName: json['app_name'],
      isActive: json['is_active'] ?? false,
      isDisabled: json['is_disabled'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      lastAccessed: json['last_accessed'] ?? '',
    );
  }
}

class AppIdentityService {
  /// 🔹 Get hardware ID
  static Future<String> _getHardwareId() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = await deviceInfoPlugin.androidInfo;
    return deviceInfo.hardware ?? 'unknown_device';
  }

  /// 🔹 Sync apps (GET ALL APPS)
  static Future<List<AppIdentity>> getMyAppIdentities() async {
    try {
      final hardwareId = await _getHardwareId();

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/app/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'hardware_id': hardwareId}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List apps = data['apps'];

        return apps.map((e) => AppIdentity.fromJson(e)).toList();
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Sync Error: $e');
      }
      return [];
    }
  }

  /// 🔹 Generate App
  static Future<AppIdentity?> generateApp({
    required String appName,
  }) async {
    try {
      final hardwareId = await _getHardwareId();

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/app/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hardware_id': hardwareId,
          'app_name': appName,
        }),
      );

      if (response.statusCode == 200) {
        return AppIdentity.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Generate Error: $e');
      }
      return null;
    }
  }


  /// 🔹 Select hardcoded app identity (upserts Security node)
  static Future<bool> selectAppIdentity(String appId, String appName) async {
    try {
      final hardwareId = await _getHardwareId();

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/auth/qr/select-app'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hardware_id': hardwareId,
          'app_id': appId,
          'app_name': appName,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Select Identity Error: $e');
      }
      return false;
    }
  }

  /// 🔹 Activate App (exclusive) — legacy endpoint
  static Future<bool> selectApp(String appId) async {
    try {
      final hardwareId = await _getHardwareId();

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/app/activate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hardware_id': hardwareId,
          'app_id': appId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Activate Error: $e');
      }
      return false;
    }
  }

  /// 🔹 Deactivate / Disable App (force stop, not delete)
  static Future<bool> deactivateApp(String appId) async {
    try {
      final hardwareId = await _getHardwareId();

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/app/deactivate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hardware_id': hardwareId,
          'app_id': appId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Deactivate Error: $e');
      }
      return false;
    }
  }

  /// 🔹 Reactivate a disabled app (backend verifies hardware_id + status)
  static Future<bool> reactivateApp(String appId) async {
    try {
      final hardwareId = await _getHardwareId();

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/app/reactivate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hardware_id': hardwareId,
          'app_id': appId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Reactivate Error: $e');
      }
      return false;
    }
  }
}
