import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HardwareSigner {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyPrivate = "starlight_hw_private_key";
  static const _keyPublic = "starlight_hw_public_key";
  static const _keyScheme = "starlight_hw_key_scheme";

  static final _ed25519 = Ed25519();

  static Future<Map<String, String>> generateKeyPair(String seed) async {
    final random = Random.secure();
    final seedBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final keyPair = await _ed25519.newKeyPairFromSeed(seedBytes);

    final keyPairData = await keyPair.extract();
    final privateKeyB64 = base64Encode(keyPairData.bytes);
    final publicKeyB64 = base64Encode(keyPairData.publicKey.bytes);

    await _storage.write(key: _keyPrivate, value: privateKeyB64);
    await _storage.write(key: _keyPublic, value: publicKeyB64);
    await _storage.write(key: _keyScheme, value: "ed25519");

    return {
      'public_key': publicKeyB64,
      'private_key': privateKeyB64,
    };
  }

  static Future<String> sign(String message) async {
    final privateKeyB64 = await _storage.read(key: _keyPrivate);
    if (privateKeyB64 == null) {
      throw Exception("Hardware key not initialized. Re-authentication required.");
    }

    final privateKeyBytes = base64Decode(privateKeyB64);
    final publicKeyB64 = await _storage.read(key: _keyPublic);
    if (publicKeyB64 == null) {
      throw Exception("Public key missing from secure storage.");
    }

    final seedBytes = Uint8List.fromList(
      privateKeyBytes.length == 32
          ? privateKeyBytes
          : sha256.convert(privateKeyBytes).bytes,
    );
    final keyPair = await _ed25519.newKeyPairFromSeed(seedBytes);
    final sig = await _ed25519.sign(
      Uint8List.fromList(utf8.encode(message)),
      keyPair: keyPair,
    );

    final result = {
      'sig': base64Encode(sig.bytes),
      'pk': publicKeyB64,
    };
    return base64Encode(utf8.encode(jsonEncode(result)));
  }

  static Future<String> buildSignatureHeader({
    required String method,
    required String path,
    String? body,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = '$method:$path:$timestamp${body != null ? ':$body' : ''}';
    final signature = await sign(message);
    return '$timestamp.$signature';
  }

  static Future<bool> verify({
    required String message,
    required String signature,
    required String publicKey,
  }) async {
    try {
      final envelope = jsonDecode(
        utf8.decode(base64Decode(signature)),
      ) as Map<String, dynamic>;
      final sigBytes = base64Decode(envelope['sig']);
      final pkBytes = base64Decode(envelope['pk']);

      final sigObj = Signature(sigBytes, publicKey: SimplePublicKey(pkBytes, type: KeyPairType.ed25519));

      return await _ed25519.verify(
        Uint8List.fromList(utf8.encode(message)),
        signature: sigObj,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<String?> getPublicKey() async {
    return await _storage.read(key: _keyPublic);
  }

  static Future<String?> getPrivateKey() async {
    return await _storage.read(key: _keyPrivate);
  }

  static Future<void> clearKeys() async {
    await _storage.delete(key: _keyPrivate);
    await _storage.delete(key: _keyPublic);
    await _storage.delete(key: _keyScheme);
  }
}
