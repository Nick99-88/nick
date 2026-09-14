import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants.dart';
import '../../../core/storage.dart';
import '../../../core/firebase_options.dart';

class FirebasePhoneService {
  static String? _verificationId;
  static int? _forceResendingToken;

  static FirebaseAuth get _auth {
    if (Firebase.apps.isEmpty) {
      throw Exception(
        'Firebase is not initialized. Call Firebase.initializeApp() first.',
      );
    }
    return FirebaseAuth.instance;
  }

  /// Ensure Firebase is initialized. Attempts to initialize if not already done.
  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) {
      // Retry Firebase initialization with backoff if plugins weren't ready in main()
      for (var attempt = 1; attempt <= 5; attempt++) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          debugPrint('🏛️ FirebasePhoneService: Firebase initialized on attempt $attempt');
          break;
        } catch (e) {
          debugPrint('🏛️ FirebasePhoneService: Firebase init attempt $attempt/5 failed: $e');
          if (attempt < 5) {
            await Future.delayed(Duration(milliseconds: attempt * 500));
          } else {
            throw Exception(
              'Firebase failed to initialize after 5 attempts. Ensure Firebase.initializeApp() has been called in main() and plugins are registered in MainActivity.',
            );
          }
        }
      }
    }
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: kDebugMode,
      forceRecaptchaFlow: false,
    );
    if (kDebugMode) {
      debugPrint('🏛️ Firebase Phone Auth service ready');
    }
  }

  /// Send OTP to a Pakistan phone number.
  /// Returns true if the SMS was dispatched (codeSent callback fired).
  static Future<bool> sendOTPToPakistan(String phoneNumber) async {
    try {
      final formattedNumber = _formatPakistanNumber(phoneNumber);

      if (kDebugMode) {
        debugPrint('🏛️ Sending OTP to: $formattedNumber');
      }

      bool codeSent = false;

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (kDebugMode) {
            debugPrint('🏛️ Auto verification completed');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) {
            debugPrint('🏛️ Verification failed: ${e.message}');
          }
          throw Exception('Phone verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? forceResendingToken) {
          _verificationId = verificationId;
          _forceResendingToken = forceResendingToken;
          codeSent = true;
          if (kDebugMode) {
            debugPrint('🏛️ OTP sent — verificationId: $verificationId');
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (kDebugMode) {
            debugPrint('🏛️ Auto-retrieval timeout');
          }
        },
        forceResendingToken: _forceResendingToken,
      );

      return codeSent;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error sending OTP: $e');
      }
      return false;
    }
  }

  /// Verify the OTP code entered by the user.
  static Future<bool> verifyOTP(String otpCode) async {
    if (_verificationId == null) {
      throw Exception('No verification ID. Request OTP first.');
    }

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        if (kDebugMode) {
          debugPrint('🏛️ Verifying OTP (attempt ${attempt + 1}): $otpCode');
        }

        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otpCode,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        if (kDebugMode) {
          debugPrint('🏛️ Phone auth success — uid: ${userCredential.user?.uid}');
          debugPrint('🏛️ Phone: ${userCredential.user?.phoneNumber}');
        }

        return true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('🏛️ OTP verify attempt ${attempt + 1} failed: $e');
        }
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return false;
  }

  static User? get currentUser => _auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  static String get apiToken => 'Ae0iMNeW7HCfBtrCj-eV3TC1kNBqCKS0MGzaX-JVQc4J0SVsbdbNNLkR_OTWU6c3hQsIuWNqu1XyKEKOelbMBpNmyW66doxE5OlzVSKcH-POfp0wImPx6aDKV1vRFdJ6GtYbhkOLV9S5vB9Q-zVfnCW9mg';

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      _verificationId = null;
      _forceResendingToken = null;
      if (kDebugMode) {
        debugPrint('🏛️ Signed out');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Sign out error: $e');
      }
    }
  }

  /// Format a raw Pakistan number to +92XXXXXXXXXX.
  static String _formatPakistanNumber(String phoneNumber) {
    String digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (digits.startsWith('+92')) {
      // already correct
    } else if (digits.startsWith('92') && digits.length >= 12) {
      digits = '+$digits';
    } else if (digits.startsWith('0')) {
      digits = '+92${digits.substring(1)}';
    } else {
      digits = '+92$digits';
    }

    final raw = digits.replaceAll(RegExp(r'[^\d]'), '');
    if (!raw.startsWith('92') || raw.length != 12) {
      throw Exception(
        'Invalid Pakistan number. Expected 03XXXXXXXX or +92XXXXXXXXXX.',
      );
    }

    return digits;
  }

  static String formatPakistanNumber(String phoneNumber) {
    try {
      final formatted = _formatPakistanNumber(phoneNumber);
      final digits = formatted.substring(3); // strip +92
      return '0${digits.substring(0, 3)} ${digits.substring(3)}';
    } catch (_) {
      return phoneNumber;
    }
  }

  static bool isValidPakistanNumber(String phoneNumber) {
    try {
      _formatPakistanNumber(phoneNumber);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifyWithServer(
    String phoneNumber,
    String firebaseToken,
    String firebaseUid,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/firebase/verify-phone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await StarlightStorage.getUserToken()}',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'firebase_token': firebaseToken,
          'firebase_uid': firebaseUid,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) {
          debugPrint('🏛️ Server verification: ${data['message']}');
        }
        return data['phone_verified'] ?? false;
      } else {
        if (kDebugMode) {
          debugPrint('🏛️ Server verification failed: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Server verification error: $e');
      }
      return false;
    }
  }

  static Future<bool> checkServerVerificationStatus() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${StarlightConstants.apiBaseUrl}/firebase/check-verification',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await StarlightStorage.getUserToken()}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isVerified = data['phone_verified'] ?? false;

        if (isVerified && data['verified_phone_number'] != null) {
          await StarlightStorage.setVerifiedPhone(
            data['verified_phone_number'],
          );
          await StarlightStorage.setChatVerified(true);
        }

        return isVerified;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Check verification error: $e');
      }
      return false;
    }
  }
}
