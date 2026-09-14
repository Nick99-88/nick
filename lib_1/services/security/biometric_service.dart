import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import '../../core/storage.dart';
import 'audit_logger.dart';

/// Service for biometric authentication (fingerprint/face recognition)
/// Used for app lock and security features
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final AuditLogger _auditLogger = AuditLogger();

  /// Check if biometric authentication is available on device
  Future<bool> isAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) return false;

      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isDeviceSupported;
    } catch (e) {
      debugPrint('🏛️ BiometricService: Availability check failed');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('🏛️ BiometricService: Failed to get biometrics: $e');
      return [];
    }
  }

  /// Authenticate user with biometrics
  /// Returns true if authentication successful
  Future<bool> authenticate({
    String localizedReason = 'Authenticate to access Starlight Console',
    bool biometricOnly = false,
  }) async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
      );
      
      if (authenticated) {
        HapticFeedback.mediumImpact();
        debugPrint('🏛️ BiometricService: Authentication successful');
        await _auditLogger.logEvent(SecurityEventType.biometricAuth);
      } else {
        await _auditLogger.logEvent(SecurityEventType.biometricAuthFailed);
      }
      
      return authenticated;
    } catch (e) {
      debugPrint('🏛️ BiometricService: Authentication failed');
      await _auditLogger.logEvent(SecurityEventType.biometricAuthFailed);
      return false;
    }
  }

  /// Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    return await StarlightStorage.getBiometricLockEnabled() ?? false;
  }

  /// Enable/disable app lock
  Future<void> setAppLockEnabled(bool enabled) async {
    await StarlightStorage.setBiometricLockEnabled(enabled);
    if (enabled) {
      await _auditLogger.logEvent(SecurityEventType.biometricLockEnabled);
    } else {
      await _auditLogger.logEvent(SecurityEventType.biometricLockDisabled);
    }
    debugPrint('🏛️ BiometricService: App lock ${enabled ? "enabled" : "disabled"}');
  }

  /// Stop authentication (cancel ongoing auth)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      debugPrint('🏛️ BiometricService: Failed to stop authentication: $e');
    }
  }

  /// Get user-friendly biometric type name
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      default:
        return 'Biometric';
    }
  }
}
