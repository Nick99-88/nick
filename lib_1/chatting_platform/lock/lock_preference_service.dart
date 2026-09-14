import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'lock_preference.dart';

class LockPreferenceService {
  static const String _key = 'chat_lock_preferences';

  static Future<LockPreference> get() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return const LockPreference();
    try {
      return LockPreference.fromMap(jsonDecode(raw));
    } catch (_) {
      return const LockPreference();
    }
  }

  static Future<void> save(LockPreference pref) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(pref.toMap()));
  }

  static Future<bool> isLockEnabled() async {
    final pref = await get();
    return pref.isEnabled;
  }

  static Future<void> reset() async {
    await save(const LockPreference());
  }
}
