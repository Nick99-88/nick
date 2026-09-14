import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/storage.dart';
import '../core/starlight_secure_storage.dart';

/// Central JWT lifecycle manager.
/// On every 401, silently re-exchanges the hardware-bound master_key
/// for a fresh JWT — no re-login required.
class TokenManager {
  TokenManager._();
  static final TokenManager instance = TokenManager._();

  static const String _baseUrl = StarlightConstants.apiBaseUrl;

  /// Prevents thundering herd: multiple concurrent 401s share one refresh.
  Completer<String>? _refreshing;

  /// ── Public API ──────────────────────────────────────────────────────

  /// Returns a valid (possibly refreshed) token. Throws if recovery fails.
  Future<String> getValidToken() async {
    final token = await StarlightStorage.getUserToken();
    if (token == null) throw Exception('No stored session');

    if (!_isExpired(token)) return token;

    return _recoverToken();
  }

  /// Call this when any request returns 401.
  Future<String> refreshBecause401() => _recoverToken();

  /// ── Internals ───────────────────────────────────────────────────────

  bool _isExpired(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return true; // malformed → treat as expired
      final padded = base64Url.normalize(parts[1]);
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(padded)),
      );
      final exp = payload['exp'] as int?;
      if (exp == null) return false; // no expiry claim → assume valid
      // Expire 30 seconds early to avoid edge races
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp - 30;
    } catch (_) {
      return true;
    }
  }

  Future<String> _recoverToken() async {
    // Deduplicate: if another caller is already refreshing, wait on it.
    if (_refreshing != null && !_refreshing!.isCompleted) {
      return _refreshing!.future;
    }

    _refreshing = Completer<String>();
    try {
      final fresh = await _doSilentRecovery();
      _refreshing!.complete(fresh);
      return fresh;
    } catch (e) {
      _refreshing!.completeError(e);
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  Future<String> _doSilentRecovery() async {
    final masterKey = await StarlightSecureVault.getMasterKey();
    final deviceId = await StarlightSecureVault.getDeviceId();
    final expiredJwt = await StarlightStorage.getUserToken();

    if (masterKey == null || deviceId == null) {
      throw Exception('Hardware credentials missing — re-login required');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = '$deviceId|$timestamp';
    final sig = Hmac(
      sha256,
      utf8.encode(masterKey),
    ).convert(utf8.encode(payload));

    debugPrint('🔐 TokenManager: silent recovery for device $deviceId');

    final response = await http
        .post(
          Uri.parse('$_baseUrl/auth/silent-recovery'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'device_id': deviceId,
            'signature': sig.toString(),
            'payload': payload,
            'expired_jwt': expiredJwt,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(
        'Silent recovery failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final freshToken = data['access_token'] as String?;

    if (freshToken == null) {
      throw Exception('Silent recovery returned no access_token');
    }

    // Persist the new JWT
    await StarlightStorage.setUserToken(freshToken);

    // Persist user ID from the new JWT
    try {
      final parts = freshToken.split('.');
      if (parts.length == 3) {
        final padded = base64Url.normalize(parts[1]);
        final claims = jsonDecode(utf8.decode(base64Url.decode(padded)));
        final userId = claims['sub'] as String?;
        if (userId != null) await StarlightStorage.setUserId(userId);
      }
    } catch (_) {}

    // Persist role
    if (data['role'] != null) {
      await StarlightStorage.setUserRole(data['role']);
    }

    debugPrint('🔐 TokenManager: JWT refreshed successfully');
    return freshToken;
  }
}
