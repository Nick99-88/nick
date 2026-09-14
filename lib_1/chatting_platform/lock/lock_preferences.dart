import 'package:shared_preferences/shared_preferences.dart';
import 'lock_preference.dart';

class LockPreferences {
  static const String _keyIsEnabled = 'is_enabled';

  static Future<LockPreference> getLockPreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_keyIsEnabled) ?? false;

    return LockPreference(
      isEnabled: isEnabled,
      lockType: isEnabled ? LockType.biometrics : LockType.none,
    );
  }

  static Future<void> saveLockPreference(LockPreference preference) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsEnabled, preference.isEnabled);
  }

  static Future<bool> isLockEnabled() async {
    final pref = await getLockPreference();
    return pref.isEnabled;
  }

  static Future<void> reset() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsEnabled, false);
  }
}