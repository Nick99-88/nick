import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage.dart';
import '../../core/platform_gate.dart';

/// Security event types for audit logging
enum SecurityEventType {
  biometricAuth,
  biometricAuthFailed,
  biometricLockEnabled,
  biometricLockDisabled,
  rolePinEnabled,
  rolePinDisabled,
  rolePinVerification,
  qrLoginGenerated,
  qrLoginScanned,
  qrLoginFailed,
  qrTransferGenerated,
  qrTransferCompleted,
  qrTransferCancelled,
  mfaEnabled,
  mfaDisabled,
  phoneVerified,
  emailVerified,
  accountTransferInitiated,
  accountTransferCompleted,
  sessionWiped,
  appLockTimeoutChanged,
}

/// Audit logging service for security events
/// Logs important security events for forensic analysis
class AuditLogger {
  static final AuditLogger _instance = AuditLogger._internal();
  factory AuditLogger() => _instance;
  AuditLogger._internal();

  /// Log a security event
  Future<void> logEvent(SecurityEventType type, {Map<String, dynamic>? details}) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final deviceId = await PlatformGate.getDeviceId();
      final userId = await _getUserId();
      
      final event = {
        'timestamp': timestamp,
        'event_type': type.toString().split('.').last,
        'device_id': deviceId,
        'user_id': userId,
        'details': details ?? {},
      };

      // Store in local storage for offline access
      await _storeEventLocally(event);
      
      // Also print to console for debugging
      if (kDebugMode) {
        debugPrint('🔒 AUDIT: ${event['event_type']} - ${details?.toString() ?? ""}');
      }
    } catch (e) {
      debugPrint('🏛️ AuditLogger: Failed to log event: $e');
    }
  }

  /// Get recent audit events
  Future<List<Map<String, dynamic>>> getRecentEvents({int limit = 50}) async {
    try {
      final prefs = await _getPrefs();
      final eventsJson = prefs.getStringList('audit_events') ?? [];
      
      final events = eventsJson
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
      
      // Sort by timestamp descending
      events.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      
      return events.take(limit).toList();
    } catch (e) {
      debugPrint('🏛️ AuditLogger: Failed to get events: $e');
      return [];
    }
  }

  /// Clear audit logs
  Future<void> clearLogs() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove('audit_events');
      debugPrint('🏛️ AuditLogger: Logs cleared');
    } catch (e) {
      debugPrint('🏛️ AuditLogger: Failed to clear logs: $e');
    }
  }

  /// Export logs as JSON string
  Future<String> exportLogs() async {
    final events = await getRecentEvents(limit: 1000);
    return jsonEncode(events);
  }

  Future<void> _storeEventLocally(Map<String, dynamic> event) async {
    try {
      final prefs = await _getPrefs();
      final eventsJson = prefs.getStringList('audit_events') ?? [];
      
      // Add new event
      eventsJson.add(jsonEncode(event));
      
      // Keep only last 1000 events to prevent storage bloat
      if (eventsJson.length > 1000) {
        eventsJson.removeRange(0, eventsJson.length - 1000);
      }
      
      await prefs.setStringList('audit_events', eventsJson);
    } catch (e) {
      debugPrint('🏛️ AuditLogger: Failed to store event: $e');
    }
  }

  Future<String?> _getUserId() async {
    try {
      final userData = await StarlightStorage.getUserData();
      return userData?['id']?.toString();
    } catch (e) {
      return null;
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    return SharedPreferences.getInstance();
  }

  /// Get formatted human-readable log
  Future<String> getFormattedLogs() async {
    final events = await getRecentEvents(limit: 100);
    final buffer = StringBuffer();
    
    buffer.writeln('=== STARLIGHT SECURITY AUDIT LOG ===');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('Total Events: ${events.length}');
    buffer.writeln('');
    
    for (final event in events) {
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(
        DateTime.parse(event['timestamp']),
      );
      final type = event['event_type'];
      final details = event['details'];
      
      buffer.writeln('[$timestamp] $type');
      if (details != null && details.isNotEmpty) {
        details.forEach((key, value) {
          buffer.writeln('  $key: $value');
        });
      }
      buffer.writeln('');
    }
    
    return buffer.toString();
  }
}
