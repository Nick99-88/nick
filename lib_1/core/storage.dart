import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode, utf8, base64Url;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'constants.dart';
import 'hardware_signer.dart';
import 'starlight_secure_storage.dart';

class StarlightStorage {
  // 🏛️ Key Constants
  static const String _keyIntroSeen = "intro_seen_token";
  static const String _keyIntroSeenPrefix = "intro_seen_";
  static const String _keyOnboardingCompleted = "onboarding_completed";
  static const String _keyAppId = "active_app_id";
  static const String _keyAppName = "active_app_name";
  static const String _keyUserToken = "user_vault_token";
  static const String _keyUserRole = "user_role_type";
  static const String _keyHasIdentity = "has_identity_record";
  static const String _keyInstToken = "institutional_vault_token";
  static const String _keyUserPublicId = "user_public_id";
  static const String _keyFcmToken = "last_synced_fcm_token";
  static const String _keyIdentityVerifyToken = "id_verification_token";
  static const String _keyOwnerVerifyToken = "ownership_check_token";
  static const String _keyChatVerified = "is_chat_verified_v1";
  static const String _keyHasInstitution = "has_institution_status";
  static const String _keyPhoneVerified = "is_phone_verified";
  static const String _keyPhoneNumber = "user_phone_number";
  static const String _keyDashboardData = "dashboard_stats_data";
  static const String _keyFirebaseUserId = "firebase_user_id";
  static const String _keyVerifiedPhone = "verified_phone_number";
  static const String _keyUserEmail = "user_email";

  // 🏛️ Parent-Child Link Keys
  static const String _keyParentLinkToken = "parent_link_token";
  static const String _keyParentChildLinked = "parent_child_linked";

  // 🏛️ Wallet Cache Keys
  static const String _keyCachedGold = "cached_wallet_gold";
  static const String _keyCachedSilver = "cached_wallet_silver";
  static const String _keyCachedAiCredits = "cached_wallet_ai_credits";
  static const String _keyCachedSubscriptions = "cached_active_subscriptions";
  static const String _keyWalletLastSynced = "cached_wallet_last_synced";

  // --- 🔒 CORE LOGIC ---

  static Future<SharedPreferences> get _instance async =>
      await SharedPreferences.getInstance();

  static Completer<String?>? _refreshing;

  static Future<void> _writeString(String key, String value) async {
    final p = await _instance;
    await p.setString(key, value);
  }

  static Future<void> _writeBool(String key, bool value) async {
    final p = await _instance;
    await p.setBool(key, value);
  }

  static Future<String?> getLastFcmToken() async {
    final p = await _instance;
    return p.getString(_keyFcmToken);
  }

  /// 🏛️ CASE: Chat Identity Verification Status
  static Future<void> setChatVerified(bool status) async {
    final p = await _instance;
    await p.setBool(_keyChatVerified, status);
  }

  static Future<bool> isChatVerified() async {
    final p = await _instance;
    return p.getBool(_keyChatVerified) ?? false;
  }

  // --- 🔓 GETTERS (READ) ---

  static Future<bool?> getIntroToken() async =>
      (await _instance).getBool(_keyIntroSeen);

  static Future<String?> getAppId() async =>
      (await _instance).getString(_keyAppId);

  static Future<String?> getAppName() async =>
      (await _instance).getString(_keyAppName);

  static Future<String?> getUserToken() async {
    final token = (await _instance).getString(_keyUserToken);
    if (token == null) return null;
    if (!_isExpiredJwt(token)) return token;
    return _refreshTokenIfNeeded();
  }

  /// Returns the raw stored token WITHOUT attempting refresh.
  /// Used for offline fallback routing — if a token exists (even expired),
  /// the user was previously logged in and should be routed via local data.
  static Future<String?> getRawUserToken() async =>
      (await _instance).getString(_keyUserToken);

  static bool _isExpiredJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return true;
      final padded = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(padded)));
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 30;
    } catch (_) {
      return true;
    }
  }

  static Future<String?> _refreshTokenIfNeeded() async {
    if (_refreshing != null && !_refreshing!.isCompleted) {
      return _refreshing!.future;
    }

    _refreshing = Completer<String?>();
    try {
      final fresh = await _doSilentRecovery();
      _refreshing!.complete(fresh);
      return fresh;
    } catch (e) {
      _refreshing!.completeError(e);
      return null;
    } finally {
      _refreshing = null;
    }
  }

  static Future<String?> _doSilentRecovery() async {
    final masterKey = await StarlightSecureVault.getMasterKey();
    final deviceId = await StarlightSecureVault.getDeviceId();
    final expiredJwt = (await _instance).getString(_keyUserToken);

    if (masterKey == null || deviceId == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = '$deviceId|$timestamp';
    final sig = Hmac(sha256, utf8.encode(masterKey)).convert(utf8.encode(payload));

    debugPrint('🔐 Storage: auto-refreshing expired JWT');

    final response = await http.post(
      Uri.parse('${StarlightConstants.apiBaseUrl}/auth/silent-recovery'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': deviceId,
        'signature': sig.toString(),
        'payload': payload,
        'expired_jwt': expiredJwt,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      debugPrint('❌ Storage: silent recovery failed (${response.statusCode})');
      return null;
    }

    final data = jsonDecode(response.body);
    final freshToken = data['access_token'] as String?;
    if (freshToken == null) return null;

    await (await _instance).setString(_keyUserToken, freshToken);

    try {
      final parts = freshToken.split('.');
      if (parts.length == 3) {
        final padded = base64Url.normalize(parts[1]);
        final claims = jsonDecode(utf8.decode(base64Url.decode(padded)));
        final userId = claims['sub'] as String?;
        if (userId != null) await setUserId(userId);
      }
    } catch (_) {}

    if (data['role'] != null) {
      await (await _instance).setString(_keyUserRole, data['role']);
    }

    debugPrint('🔐 Storage: JWT refreshed successfully');
    return freshToken;
  }

  static Future<String?> getUserRole() async =>
      (await _instance).getString(_keyUserRole);

  static Future<String?> getInstitutionalToken() async =>
      (await _instance).getString(_keyInstToken);

  static Future<String?> getUserPublicId() async =>
      (await _instance).getString(_keyUserPublicId);
  static String? _cachedUserUuid;

  static String? getCachedUserUuid() => _cachedUserUuid;

  static Future<String?> getUserUuid() async {
    if (_cachedUserUuid != null) return _cachedUserUuid;
    final token = await getUserToken();
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload);
      _cachedUserUuid = map['sub']?.toString();
      return _cachedUserUuid;
    } catch (_) {
      return null;
    }
  }
  static const String _keyUserName = "synced_user_name";
  static const String _keyInstName = "synced_institution_name";

  static Future<bool?> getIdentity() async {
    final p = await _instance;
    return p.getBool(_keyHasIdentity);
  }

  // 🏛️ New Getters
  static Future<String?> getIdentityVerifyToken() async =>
      (await _instance).getString(_keyIdentityVerifyToken);

  static Future<String?> getOwnerVerifyToken() async =>
      (await _instance).getString(_keyOwnerVerifyToken);

  // --- 💾 SETTERS (SAVE) ---

  static Future<void> setIntroToken(bool seen) async =>
      await _writeBool(_keyIntroSeen, seen);

  static Future<bool?> getIntroSeenFor(String feature) async =>
      (await _instance).getString('${_keyIntroSeenPrefix}$feature') == 'seen';

  static Future<void> setIntroSeenFor(String feature) async =>
      await _writeString('${_keyIntroSeenPrefix}$feature', 'seen');

  static Future<bool> isOnboardingCompleted() async {
    final p = await _instance;
    return p.getBool(_keyOnboardingCompleted) ?? false;
  }

  static Future<void> setOnboardingCompleted() async {
    await _writeBool(_keyOnboardingCompleted, true);
  }

  static Future<void> setAppId(String id) async =>
      await _writeString(_keyAppId, id);

  static Future<void> setActiveAppName(String name) async =>
      await _writeString(_keyAppName, name);

  static Future<void> setUserRole(String role) async =>
      await _writeString(_keyUserRole, role);

  static Future<void> setIdentity(bool status) async =>
      await _writeBool(_keyHasIdentity, status);

  static Future<void> setInstitutionalToken(String token) async =>
      await _writeString(_keyInstToken, token);

  // 🏛️ New Setters
  static Future<void> setIdentityVerifyToken(String token) async =>
      await _writeString(_keyIdentityVerifyToken, token);

  static Future<void> setOwnerVerifyToken(String token) async =>
      await _writeString(_keyOwnerVerifyToken, token);

  static Future<void> saveUserSession(String token, String publicId) async {
    final p = await _instance;
    await p.setString(_keyUserToken, token);
    await p.setString(_keyUserPublicId, publicId);
  }

  static Future<void> saveIdentity(String userName, String instName) async {
    final p = await _instance;
    await p.setString(_keyUserName, userName);
    await p.setString(_keyInstName, instName);
  }

  static Future<Map<String, String>> getIIdentity() async {
    final p = await _instance;
    return {
      "user": p.getString(_keyUserName) ?? "Admin",
      "institution": p.getString(_keyInstName) ?? "Starlight"
    };
  }

  // --- 🧹 CLEARING & RESETTING CASES ---

  /// 🏛️ CASE: Full Factory Reset
  static Future<void> clearAll() async {
    final p = await _instance;
    await p.clear();
    await StarlightSecureVault.purgeVault();
    await HardwareSigner.clearKeys();
  }

  /// 🏛️ CASE: Clear App Identity (switch to identity screen)
  static Future<void> clearAppIdentity() async {
    final p = await _instance;
    await p.remove(_keyAppId);
    await p.remove(_keyAppName);
  }

  /// 🏛️ CASE: User Logout
  /// Wipes session but preserves hardware-linked AppId and Intro status.
  static Future<void> logout() async {
    final p = await _instance;
    await p.remove(_keyUserToken);
    await p.remove(_keyUserRole);
    await p.remove(_keyUserPublicId);
    await p.remove(_keyHasIdentity);
    await p.remove(_keyInstToken);
    await p.remove(_keyIdentityVerifyToken);
    await p.remove(_keyOwnerVerifyToken);
    await p.remove(_keyStaffAccess);

    // Purge hardware-bound credentials so silent recovery cannot be attempted.
    await StarlightSecureVault.purgeVault();
    await HardwareSigner.clearKeys();
  }

  /// 🏛️ CASE: Switch Institution
  static Future<void> resetInstitution() async {
    final p = await _instance;
    await p.remove(_keyInstToken);
    await p.remove(_keyOwnerVerifyToken);
  }

  // --- 🛠️ UTILS ---

  static Future<void> ensureInitialized() async {
    try {
      final p = await SharedPreferences.getInstance();
      debugPrint("🏛️ Starlight Storage Vault: Online");
    } catch (e) {
      debugPrint("🏛️ Storage System Failed: $e");
    }
  }

  static Future<void> saveFcmToken(String token) async {
    final p = await _instance;
    await p.setString(_keyFcmToken, token);
  }

  static Future<void> restoreFromVault(String key, String value) async {
    final p = await _instance;
    await p.setString(key, value);
  }

  static Future<void> setUserPfp(String base64) async {
    final p = await _instance;
    await p.setString("user_pfp_base64", base64);
  }

  static Future<String?> getUserPfp() async {
    final p = await _instance;
    return p.getString("user_pfp_base64");
  }

  // --- 🏛️ SETUP DATA STORAGE ---

  /// 🏛️ Institution Status
  static Future<void> setHasInstitution(bool status) async =>
      await _writeBool(_keyHasInstitution, status);

  static Future<bool> hasInstitution() async {
    final p = await _instance;
    return p.getBool(_keyHasInstitution) ?? false;
  }

  /// 🏛️ Phone Verification Status
  static Future<void> setPhoneVerified(bool status) async =>
      await _writeBool(_keyPhoneVerified, status);

  static Future<bool> isPhoneVerified() async {
    final p = await _instance;
    return p.getBool(_keyPhoneVerified) ?? false;
  }

  /// 🏛️ Chat Verification Status
  static Future<bool?> getChatVerified() async {
    final p = await _instance;
    return p.getBool(_keyChatVerified);
  }

  /// 🏛️ Phone Number
  static Future<void> setUserPhoneNumber(String phone) async =>
      await _writeString(_keyPhoneNumber, phone);

  static Future<String?> getUserPhoneNumber() async =>
      (await _instance).getString(_keyPhoneNumber);

  /// 🏛️ Dashboard Data
  static Future<void> setDashboardData(String data) async =>
      await _writeString(_keyDashboardData, data);

  static Future<String?> getDashboardData() async =>
      (await _instance).getString(_keyDashboardData);

  /// 🏛️ Get Dashboard Stats as Map
  static Future<Map<String, dynamic>?> getDashboardStats() async {
    final data = await getDashboardData();
    if (data != null) {
      try {
        return jsonDecode(data);
      } catch (e) {
        debugPrint("🏛️ Dashboard Data Parse Error: $e");
        return null;
      }
    }
    return null;
  }

  /// 🏛️ Set Dashboard Stats
  static Future<void> setDashboardStats({
    required int students,
    required int teachers,
    required int staff,
  }) async {
    final stats = {
      'students': students,
      'teachers': teachers,
      'staff': staff,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await setDashboardData(jsonEncode(stats));
  }

  /// 🏛️ Firebase User ID
  static Future<void> setFirebaseUserId(String uid) async =>
      await _writeString(_keyFirebaseUserId, uid);

  static Future<String?> getFirebaseUserId() async =>
      (await _instance).getString(_keyFirebaseUserId);

  /// 🏛️ Verified Phone Number
  static Future<void> setVerifiedPhone(String? phone) async {
    final p = await _instance;
    if (phone == null) {
      await p.remove(_keyVerifiedPhone);
    } else {
      await p.setString(_keyVerifiedPhone, phone);
    }
  }

  static Future<String?> getVerifiedPhone() async =>
      (await _instance).getString(_keyVerifiedPhone);

  /// 🏛️ Firebase Token for API
  static Future<void> setFirebaseToken(String token) async =>
      await _writeString('firebase_token', token);

  static Future<String?> getFirebaseToken() async =>
      (await _instance).getString('firebase_token');

  /// 🏛️ User ID
  static Future<void> setUserId(dynamic id) async =>
      await _writeString('user_id', id.toString());

  static Future<int?> getUserId() async {
    final p = await _instance;
    final idString = p.getString('user_id');
    if (idString != null) {
      return int.tryParse(idString);
    }
    return null;
  }

  static Future<String?> getUserIdString() async {
    final p = await _instance;
    return p.getString('user_id');
  }

  /// 🏛️ User Token
  static Future<void> setUserToken(String token) async =>
      await _writeString(_keyUserToken, token);

  // 🏛️ User Name
  static Future<void> setUserName(String name) async =>
      await _writeString(_keyUserName, name);

  static Future<String?> getUserName() async =>
      (await _instance).getString(_keyUserName);

  // 🏛️ Staff Access Permissions Cache
  static const String _keyStaffAccess = "staff_access_cache";

  static Future<void> setStaffAccess(String data) async =>
      await _writeString(_keyStaffAccess, data);

  static Future<String?> getStaffAccess() async =>
      (await _instance).getString(_keyStaffAccess);

  static Future<Map<String, dynamic>?> getStaffAccessMap() async {
    final data = await getStaffAccess();
    if (data != null) {
      try { return jsonDecode(data); } catch (_) { return null; }
    }
    return null;
  }

  static Future<void> clearStaffAccess() async {
    final p = await _instance;
    await p.remove(_keyStaffAccess);
  }

  /// 🏛️ User Email
  static Future<void> setUserEmail(String email) async =>
      await _writeString(_keyUserEmail, email);

  static Future<String?> getUserEmail() async =>
      (await _instance).getString(_keyUserEmail);

  // 🏛️ Parent-Child Link Management
  static Future<void> setParentLinkToken(String token) async {
    final p = await _instance;
    await p.setString(_keyParentLinkToken, token);
    await p.setBool(_keyParentChildLinked, true);
  }

  static Future<String?> getParentLinkToken() async =>
      (await _instance).getString(_keyParentLinkToken);

  static Future<bool> isParentChildLinked() async {
    final p = await _instance;
    return p.getBool(_keyParentChildLinked) ?? false;
  }

  static Future<void> clearParentLink() async {
    final p = await _instance;
    await p.remove(_keyParentLinkToken);
    await p.remove(_keyParentChildLinked);
  }

  /// 🏛️ Profile Picture Preferences
  static Future<void> saveProfilePicturePreference(String userId, String profileUrl) async {
    final p = await _instance;
    await p.setString('profile_picture_$userId', profileUrl);
  }

  static Future<String?> getProfilePicturePreference(String userId) async {
    final p = await _instance;
    return p.getString('profile_picture_$userId');
  }

  static Future<bool> hasProfilePicturePreference(String userId) async {
    final p = await _instance;
    return p.containsKey('profile_picture_$userId');
  }

  // ============================================================
  // VIDEO UPLOAD STATE PERSISTENCE
  // ============================================================

  static const String _keyUploadStatePrefix = 'video_upload_state_';

  static Future<void> saveUploadState({
    required String sessionId,
    required String filePath,
    required int totalSize,
    required int uploadedBytes,
    required int lastChunkIndex,
  }) async {
    final p = await _instance;
    await p.setString('${_keyUploadStatePrefix}${sessionId}session_id', sessionId);
    await p.setString('${_keyUploadStatePrefix}${sessionId}file_path', filePath);
    await p.setInt('${_keyUploadStatePrefix}${sessionId}total_size', totalSize);
    await p.setInt('${_keyUploadStatePrefix}${sessionId}uploaded_bytes', uploadedBytes);
    await p.setInt('${_keyUploadStatePrefix}${sessionId}last_chunk_index', lastChunkIndex);
    await p.setString('${_keyUploadStatePrefix}${sessionId}timestamp', DateTime.now().toIso8601String());
    debugPrint('📥 Upload state saved: $sessionId');
  }

  static Future<Map<String, dynamic>?> getUploadState(String sessionId) async {
    final p = await _instance;
    final path = p.getString('${_keyUploadStatePrefix}${sessionId}file_path');
    if (path == null) return null;
    return {
      'session_id': sessionId,
      'file_path': path,
      'total_size': p.getInt('${_keyUploadStatePrefix}${sessionId}total_size') ?? 0,
      'uploaded_bytes': p.getInt('${_keyUploadStatePrefix}${sessionId}uploaded_bytes') ?? 0,
      'last_chunk_index': p.getInt('${_keyUploadStatePrefix}${sessionId}last_chunk_index') ?? 0,
      'timestamp': p.getString('${_keyUploadStatePrefix}${sessionId}timestamp'),
    };
  }

  static Future<List<String>> getPendingUploadSessions() async {
    final p = await _instance;
    final keys = p.getKeys();
    final sessions = <String>{};
    for (final key in keys) {
      if (key.startsWith(_keyUploadStatePrefix) && key.endsWith('session_id')) {
        sessions.add(p.getString(key) ?? '');
      }
    }
    return sessions.where((s) => s.isNotEmpty).toList();
  }

  static Future<void> clearUploadState(String sessionId) async {
    final p = await _instance;
    final keys = p.getKeys().where((k) => k.startsWith('${_keyUploadStatePrefix}${sessionId}'));
    for (final key in keys) {
      await p.remove(key);
    }
    debugPrint('📤 Upload state cleared: $sessionId');
  }

  /// 🏛️ Get user data as a map
  static Future<Map<String, dynamic>?> getUserData() async {
    final p = await _instance;
    final userId = await getUserId();
    final userPublicId = await getUserPublicId();
    final userRole = await getUserRole();
    final userName = p.getString(_keyUserName);
    final userPfp = await getUserPfp();
    final phoneNumber = await getUserPhoneNumber();
    final verifiedPhone = await getVerifiedPhone();
    final firebaseUserId = await getFirebaseUserId();

    return {
      'id': userId,
      'public_id': userPublicId,
      'role': userRole,
      'name': userName,
      'profile_picture': userPfp,
      'phone_number': phoneNumber,
      'verified_phone': verifiedPhone,
      'firebase_user_id': firebaseUserId,
    };
  }

  // 🏛️ Active Chat Phone Management
  static Future<void> saveActiveChatPhone(String chatId, String phoneNumber) async {
    final p = await _instance;
    final key = 'active_chat_${chatId}_phone';
    await p.setString(key, phoneNumber);
    print('🏛️ Storage: Saved phone $phoneNumber for chat $chatId with key: $key');
  }

  static Future<String?> getActiveChatPhone(String chatId) async {
    final p = await _instance;
    final key = 'active_chat_${chatId}_phone';
    final phoneNumber = p.getString(key);
    print('🏛️ Storage: Retrieved phone $phoneNumber for chat $chatId with key: $key');
    return phoneNumber;
  }

  // 🏛️ Wallet Cache Management
  static Future<void> cacheWalletData({
    required int gold,
    required int silver,
    required int aiCredits,
    List<Map<String, dynamic>>? subscriptions,
  }) async {
    final p = await _instance;
    await p.setInt(_keyCachedGold, gold);
    await p.setInt(_keyCachedSilver, silver);
    await p.setInt(_keyCachedAiCredits, aiCredits);
    await p.setString(_keyCachedSubscriptions, jsonEncode(subscriptions ?? []));
    await p.setString(_keyWalletLastSynced, DateTime.now().toIso8601String());
  }

  static Future<int> getCachedGold() async {
    final p = await _instance;
    return p.getInt(_keyCachedGold) ?? 0;
  }

  static Future<int> getCachedSilver() async {
    final p = await _instance;
    return p.getInt(_keyCachedSilver) ?? 0;
  }

  static Future<int> getCachedAiCredits() async {
    final p = await _instance;
    return p.getInt(_keyCachedAiCredits) ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getCachedSubscriptions() async {
    final p = await _instance;
    final raw = p.getString(_keyCachedSubscriptions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return List<Map<String, dynamic>>.from(decoded);
    } catch (_) {
      return [];
    }
  }

  static Future<String?> getWalletLastSynced() async {
    final p = await _instance;
    return p.getString(_keyWalletLastSynced);
  }

  static Future<Map<String, dynamic>> getCachedWallet() async {
    return {
      'gold': await getCachedGold(),
      'silver': await getCachedSilver(),
      'ai_credits': await getCachedAiCredits(),
      'subscriptions': await getCachedSubscriptions(),
      'last_synced': await getWalletLastSynced(),
    };
  }

  static Future<void> clearWalletCache() async {
    final p = await _instance;
    await p.remove(_keyCachedGold);
    await p.remove(_keyCachedSilver);
    await p.remove(_keyCachedAiCredits);
    await p.remove(_keyCachedSubscriptions);
    await p.remove(_keyWalletLastSynced);
  }

  // --- 🔒 SECURITY SETTINGS ---

  static const String _keyBiometricLockEnabled = "biometric_lock_enabled";
  static const String _keyRolePinEnabled = "role_pin_enabled";
  static const String _keyRolePinHash = "role_pin_hash";
  static const String _keyLastAuthTime = "last_auth_time";
  static const String _keyAppLockTimeout = "app_lock_timeout_minutes";
  static const String _keySelectedLanguage = "selected_language";

  static Future<void> setBiometricLockEnabled(bool enabled) async {
    final p = await _instance;
    await p.setBool(_keyBiometricLockEnabled, enabled);
  }

  static Future<bool?> getBiometricLockEnabled() async {
    final p = await _instance;
    return p.getBool(_keyBiometricLockEnabled);
  }

  static Future<void> setRolePinEnabled(bool enabled) async {
    final p = await _instance;
    await p.setBool(_keyRolePinEnabled, enabled);
  }

  static Future<bool?> getRolePinEnabled() async {
    final p = await _instance;
    return p.getBool(_keyRolePinEnabled);
  }

  static Future<void> setRolePinHash(String pinHash) async {
    final p = await _instance;
    await p.setString(_keyRolePinHash, pinHash);
  }

  static Future<String?> getRolePinHash() async {
    final p = await _instance;
    return p.getString(_keyRolePinHash);
  }

  static Future<void> setLastAuthTime(int timestamp) async {
    final p = await _instance;
    await p.setInt(_keyLastAuthTime, timestamp);
  }

  static Future<int?> getLastAuthTime() async {
    final p = await _instance;
    return p.getInt(_keyLastAuthTime);
  }

  static Future<void> setAppLockTimeout(int minutes) async {
    final p = await _instance;
    await p.setInt(_keyAppLockTimeout, minutes);
  }

  static Future<int?> getAppLockTimeout() async {
    final p = await _instance;
    return p.getInt(_keyAppLockTimeout);
  }

  static const String _keyBiometricFailedAttempts = "biometric_failed_attempts";

  static Future<void> setBiometricFailedAttempts(int count) async {
    final p = await _instance;
    await p.setInt(_keyBiometricFailedAttempts, count);
  }

  static Future<int> getBiometricFailedAttempts() async {
    final p = await _instance;
    return p.getInt(_keyBiometricFailedAttempts) ?? 0;
  }

  static Future<void> clearSecuritySettings() async {
    final p = await _instance;
    await p.remove(_keyBiometricLockEnabled);
    await p.remove(_keyRolePinEnabled);
    await p.remove(_keyRolePinHash);
    await p.remove(_keyLastAuthTime);
    await p.remove(_keyAppLockTimeout);
    await p.remove(_keyBiometricFailedAttempts);
  }

  // --- 🌍 LANGUAGE SETTINGS ---

  static Future<void> setSelectedLanguage(String languageCode) async {
    final p = await _instance;
    await p.setString(_keySelectedLanguage, languageCode);
  }

  static Future<String?> getSelectedLanguage() async {
    final p = await _instance;
    return p.getString(_keySelectedLanguage);
  }
}