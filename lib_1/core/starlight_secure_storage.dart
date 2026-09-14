import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StarlightSecureVault {
  static const _storage = FlutterSecureStorage(
    // Android-specific: uses encrypted shared prefs
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyMaster = "starlight_master_key";
  static const String _keyDevice = "starlight_device_id";

  // 🏛️ Save the MasterKey permanently
  static Future<void> saveHardwareCredentials(String masterKey, String deviceId) async {
    await _storage.write(key: _keyMaster, value: masterKey);
    await _storage.write(key: _keyDevice, value: deviceId);
  }

  // 🏛️ Retrieve for Silent Handshake
  static Future<String?> getMasterKey() async => await _storage.read(key: _keyMaster);
  static Future<String?> getDeviceId() async => await _storage.read(key: _keyDevice);

  // 🏛️ Clear on formal logout
  static Future<void> purgeVault() async => await _storage.deleteAll();
}