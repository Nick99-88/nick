import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/constants.dart';
import '../../core/platform_gate.dart';
import 'package:crypto/crypto.dart';
import '../../core/starlight_secure_storage.dart';
import '../../core/storage.dart';
import '../../core/hardware_signer.dart';
import '../../core/firebase_options.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AuthService {
  final String _baseUrl = StarlightConstants.apiBaseUrl;

  // 🏛️ Firebase Auth instance (ensures Firebase is initialized first)
  static FirebaseAuth? _cachedAuth;

  FirebaseAuth get _firebaseAuth {
    if (_cachedAuth != null) return _cachedAuth!;
    if (Firebase.apps.isEmpty) {
      throw Exception("Firebase is not initialized. Call Firebase.initializeApp() first.");
    }
    _cachedAuth = FirebaseAuth.instance;
    return _cachedAuth!;
  }

  /// Ensure Firebase is initialized before any auth operation.
  /// If not initialized (e.g. hot restart), try once.
  static Future<void> ensureFirebaseReady() async {
    if (Firebase.apps.isNotEmpty) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("🏛️ AuthService: Firebase initialized");
    } catch (e) {
      debugPrint("🏛️ AuthService: Firebase init failed: $e");
      throw Exception("Firebase is not initialized. Restart the app.");
    }
  }
  
  // 🏛️ Google Sign-In instance (used to get Google credentials for mobile)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', 'openid'],
  );
  
  // 🏛️ Firebase Auth state stream
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  
  // 🏛️ Current Firebase user
  User? get currentUser => _firebaseAuth.currentUser;

  /// 🏛️ Sign in with Google using Firebase Auth (for Mobile: Android/iOS)
  Future<Map<String, dynamic>> loginWithGoogle() async {
    // Try to initialize Firebase, but don't fail if it doesn't work
    try {
      await ensureFirebaseReady();
    } catch (e) {
      debugPrint('🏛️ Google Sign-In: Firebase unavailable, proceeding without it: $e');
    }
    debugPrint('🏛️ Starting Google Sign-In flow...');
    
    try {
      // 🏛️ Step 1: Check if Google Sign-In is available
      debugPrint('🏛️ Checking Google Sign-In availability...');
      final bool isAvailable = await _googleSignIn.isSignedIn();
      debugPrint('🏛️ Google Sign-In isSignedIn: $isAvailable');
      
      // 🏛️ Step 1.5: Clear any cached Google account so the account picker
      // is always shown (e.g. after logging out of the owner profile).
      if (isAvailable) {
        await _googleSignIn.signOut();
      }
      
      // 🏛️ Step 2: Trigger Google Sign-In flow
      debugPrint('🏛️ Triggering Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('🏛️ Google Sign-In cancelled by user (returned null)');
        throw Exception("Sign-in aborted by user.");
      }
      
      debugPrint('🏛️ Google user selected: ${googleUser.email}');

      // 🏛️ Step 3: Get authentication tokens
      debugPrint('🏛️ Getting Google authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      debugPrint('🏛️ Google Auth - idToken: ${idToken != null ? "present" : "null"}, accessToken: ${accessToken != null ? "present" : "null"}');

      if (idToken == null) {
        throw Exception("Failed to get Google ID token. Check your OAuth configuration.");
      }

      // 🏛️ Step 4-5: Try Firebase Auth, fall back to Google user info
      String userEmail = googleUser.email;
      String userName = googleUser.displayName ?? googleUser.email;
      String userUid = googleUser.id;

      if (Firebase.apps.isNotEmpty) {
        try {
          debugPrint('🏛️ Creating Firebase credential...');
          final OAuthCredential credential = GoogleAuthProvider.credential(
            idToken: idToken,
            accessToken: accessToken,
          );

          debugPrint('🏛️ Signing in to Firebase...');
          debugPrint('🏛️ Current Firebase user before sign-in: ${_firebaseAuth.currentUser?.uid}');

          await _firebaseAuth.signOut();
          
          final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential)
            .timeout(const Duration(seconds: 15), onTimeout: () {
              debugPrint('🏛️ Firebase sign-in timeout!');
              throw TimeoutException("Firebase sign-in timed out after 15 seconds");
            });
            
          final User? firebaseUser = userCredential.user;
          debugPrint('🏛️ Firebase user from credential: ${firebaseUser?.uid}');

          if (firebaseUser != null) {
            userEmail = firebaseUser.email ?? userEmail;
            userName = firebaseUser.displayName ?? userName;
            userUid = firebaseUser.uid;
            debugPrint('🏛️ Firebase Sign-In successful: ${firebaseUser.uid}');
          }
        } catch (e) {
          debugPrint('🏛️ Firebase Auth step failed, using Google user info: $e');
        }
      } else {
        debugPrint('🏛️ Firebase not available, using Google user info directly');
      }

      // 🏛️ Step 6: Platform & Hardware Identity
      debugPrint('🏛️ Getting device ID...');
      final String deviceId = await PlatformGate.getDeviceId();
      final String appId = await StarlightStorage.getAppId() ?? "com.starlight.superconsole";

      // 🏛️ Step 7: Send to Starlight Backend with GOOGLE ID TOKEN
      debugPrint('🏛️ Sending Google ID token to backend: $_baseUrl/auth/google');
      debugPrint('🏛️ Request body: ${jsonEncode({
        'token': idToken.substring(0, 20) + '...',  // Show partial token for debugging
        'device_id': deviceId,
        'app_id': appId,
        'email': userEmail,
        'name': userName,
        'uid': userUid,
      })}');
      
      Map<String, dynamic> data;
      
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/auth/google/auto-create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': idToken,
            'device_id': deviceId,
            'device_name': await PlatformGate.getDeviceName(),
            'app_id': appId,
            'email': userEmail,
            'name': userName,
            'photo_url': googleUser.photoUrl,
            'uid': userUid,
          }),
        ).timeout(const Duration(seconds: 10));

          debugPrint('🏛️ Backend response status: ${response.statusCode}');
        debugPrint('🏛️ Backend response body: ${response.body}');
        
        data = jsonDecode(response.body);
        if (data['secondary_verification_required'] == true) {
          return data;
        }
        if (response.statusCode != 200) {
          debugPrint('🏛️ Backend error: ${data['detail'] ?? response.body}');
          throw Exception(data['detail'] ?? "Backend handshake failed (status: ${response.statusCode})");
        }
      } on TimeoutException catch (e) {
        debugPrint('🏛️ Backend request timeout: $e');
        throw Exception("Backend request timeout. Check your internet connection.");
      } on SocketException catch (e) {
        debugPrint('🏛️ Network error: $e');
        throw Exception("Network error. Check your internet connection.");
      } catch (e) {
        debugPrint('🏛️ Backend request error: $e');
        throw Exception("Failed to connect to backend: $e");
      }

      // 🏛️ Step 9: Finalize Hardware Binding (Starlight Custom Logic)
      debugPrint('🏛️ Finalizing hardware binding...');
      final String serverAppId = await finalizeLink(
        token: data['access_token'],
        deviceId: deviceId,
        seed: data['otk'],
      );

      data['server_app_id'] = serverAppId.toString();
      
      // 🏛️ Store user ID in local storage for chat system
      if (data['access_token'] != null) {
        await StarlightStorage.setUserToken(data['access_token']);
        debugPrint('🏛️ User token stored from Google login');
        // Decode JWT sub to get the real string user_id
        try {
          final parts = data['access_token'].split('.');
          if (parts.length == 3) {
            final padded = base64Url.normalize(parts[1]);
            final payload = utf8.decode(base64Url.decode(padded));
            final claims = jsonDecode(payload);
            final userId = claims['sub'];
            if (userId != null) {
              await StarlightStorage.setUserId(userId);
              debugPrint('🏛️ User ID from JWT sub: $userId');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to decode JWT: $e');
        }
      }
      
      // 🏛️ Store user token for authentication
      if (data['access_token'] != null) {
        await StarlightStorage.setUserToken(data['access_token']);
        debugPrint('🏛️ User token stored from Google login');
      }
      
      // 🏛️ Store user name and email for display
      if (data['user_data'] != null) {
        if (data['user_data']['name'] != null) {
          await StarlightStorage.setUserName(data['user_data']['name']);
        }
        if (data['user_data']['email'] != null) {
          await StarlightStorage.setUserEmail(data['user_data']['email']);
        }
        debugPrint('🏛️ User data stored from Google login: ${data['user_data']['name']}');
      }
      
      debugPrint('🏛️ Google Sign-In complete! User: $userEmail');
      return data;
      
    } on FirebaseAuthException catch (e) {
      debugPrint('🏛️ FirebaseAuthException: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = "An account already exists with the same email but different sign-in credentials.";
          break;
        case 'invalid-credential':
          errorMessage = "The Google credential is invalid. Check your Firebase and Google Sign-In configuration.";
          break;
        case 'operation-not-allowed':
          errorMessage = "Google Sign-In is not enabled in Firebase Console.";
          break;
        case 'user-disabled':
          errorMessage = "This user account has been disabled.";
          break;
        case 'user-not-found':
          errorMessage = "No user found with this credential.";
          break;
        case 'network-request-failed':
          errorMessage = "Network error. Please check your internet connection.";
          break;
        default:
          errorMessage = "Firebase Auth Error: ${e.message}";
      }
      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      debugPrint('🏛️ Google Sign-In Error: $e');
      debugPrint('🏛️ Stack trace: $stackTrace');
      throw Exception("Google Sign-In Failed: ${e.toString()}");
    }
  }

  /// 🏛️ Sign in with Google on Web using Firebase Auth Popup
  /// 
  /// ⚠️ NOTE: Web uses Firebase ID token which requires backend to verify
  /// via Firebase Admin SDK. If your backend expects Google ID token only,
  /// use the Google Sign-In JS SDK directly instead of Firebase Auth for web.
  Future<Map<String, dynamic>> loginWithGoogleWeb() async {
    await ensureFirebaseReady();
    try {
      debugPrint('🏛️ Starting Google Sign-In for Web...');
      
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.setCustomParameters({'prompt': 'select_account'});

      final UserCredential userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception("Firebase sign-in failed.");
      }

      // For web, we get Firebase ID token
      // Your backend needs to support Firebase token verification
      final String? firebaseIdToken = await firebaseUser.getIdToken();
      final String deviceId = await PlatformGate.getDeviceId();
      final String appId = await StarlightStorage.getAppId() ?? "com.starlight.superconsole";

      debugPrint('🏛️ Web: Sending Firebase ID token to backend...');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': firebaseIdToken,
          'device_id': deviceId,
          'app_id': appId,
          'email': firebaseUser.email,
          'name': firebaseUser.displayName,
          'photo_url': firebaseUser.photoURL,
          'uid': firebaseUser.uid,
          'platform': 'web',  // 🏛️ Let backend know this is a Firebase token
        }),
      );

      debugPrint('🏛️ Web: Backend response status: ${response.statusCode}');

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        // If backend returns 401, it might not support Firebase tokens
        if (response.statusCode == 401) {
          throw Exception("Backend doesn't support Firebase tokens. Please use mobile app or update backend.");
        }
        throw Exception(data['detail'] ?? "Backend handshake failed");
      }

      final String serverAppId = await finalizeLink(
        token: data['access_token'],
        deviceId: deviceId,
        seed: data['otk'],
      );

      data['server_app_id'] = serverAppId.toString();
      return data;
      
    } on FirebaseAuthException catch (e) {
      throw Exception("Firebase Auth Error: ${e.message}");
    } catch (e) {
      throw Exception("Starlight Auth Engine Error: ${e.toString()}");
    }
  }

  /// 🏛️ Unified Google Sign-In that automatically selects the right method
  Future<Map<String, dynamic>> signInWithGoogleUnified() async {
    if (kIsWeb) {
      return await loginWithGoogleWeb();
    } else {
      return await loginWithGoogle();
    }
  }

  /// 🏛️ Sign out from both Firebase and Google
  Future<void> signOutGoogle() async {
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    await _googleSignIn.disconnect();
    debugPrint('🏛️ Signed out from Firebase and Google');
  }

  /// 🏛️ Check if user is currently signed in to Firebase
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    required String appId,
    required String deviceId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_name': name,
        'user_email': email,
        'user_password': password,
        'app_id': appId,
        'device_id': deviceId,
      }),
    );

    debugPrint("👉 SIGNUP STATUS: ${response.statusCode}");
    debugPrint("👉 SIGNUP BODY: ${response.body}");

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['status'] == 'success') {
      return data;
    } else {
      throw Exception(data['detail'] ?? "Signup failed");
    }
  }

  Future<Map<String, dynamic>> verifyOTP(String email, String otp, String action) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'action': action,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? "Verification failed.");
  }

  Future<Map<String, dynamic>> resendOTP(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/resend-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? "Could not resend code.");
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? "Recovery request failed.");
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'new_password': newPassword,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? "Password update failed.");
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final String deviceId = await PlatformGate.getDeviceId();
    final String deviceName = await PlatformGate.getDeviceName();
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_id': deviceId,
        'device_name': deviceName,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // 🏛️ Store user token and decode JWT sub for correct string user_id
      if (data['access_token'] != null) {
        await StarlightStorage.setUserToken(data['access_token']);
        debugPrint('🏛️ User token stored from email login');
        try {
          final parts = data['access_token'].split('.');
          if (parts.length == 3) {
            final padded = base64Url.normalize(parts[1]);
            final payload = utf8.decode(base64Url.decode(padded));
            final claims = jsonDecode(payload);
            final userId = claims['sub'];
            if (userId != null) {
              await StarlightStorage.setUserId(userId);
              debugPrint('🏛️ User ID from JWT sub: $userId');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to decode JWT: $e');
        }
      }
      
      // 🏛️ Store user name and email for display
      if (data['user_data'] != null) {
        if (data['user_data']['name'] != null) {
          await StarlightStorage.setUserName(data['user_data']['name']);
        }
        if (data['user_data']['email'] != null) {
          await StarlightStorage.setUserEmail(data['user_data']['email']);
        }
        debugPrint('🏛️ User data stored from email login: ${data['user_data']['name']}');
      }
      
      // 🏛️ Normalize for consistency
      if (data['role_id'] != null) data['role_id'] = data['role_id'].toString();
      return data;
    } else {
      throw Exception(data['detail'] ?? "Login failed");
    }
  }

  Future<String> finalizeLink({
    required String token,
    required String deviceId,
    required String seed,
  }) async {
    // Step 1: compute HMAC master_key (same as before)
    var key = utf8.encode(seed);
    var bytes = utf8.encode(deviceId);
    var hmacSha256 = Hmac(sha256, key);
    var digest = hmacSha256.convert(bytes);
    final String masterKey = digest.toString();

    // Step 2: generate asymmetric key pair from the seed
    final keyPair = await HardwareSigner.generateKeyPair(seed);
    final String publicKey = keyPair['public_key']!;

    // Step 3: get device location (fire-and-forget, non-blocking)
    final locationData = await _getLocation();

    // Step 4: send master_key + public_key + location to backend
    final body = <String, dynamic>{
      'master_key': masterKey,
      'device_id': deviceId,
      'public_key': publicKey,
    };
    if (locationData != null) {
      body.addAll(locationData);
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/finalize-link'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final String serverAppId =
          (responseData['app_id'] ?? '').toString();

      await StarlightSecureVault.saveHardwareCredentials(masterKey, deviceId);
      if (serverAppId.isNotEmpty) {
        await StarlightStorage.setAppId(serverAppId);
      }

      debugPrint("🏛️ Device Bound Successfully: $serverAppId");
      return serverAppId;
    } else {
      final errorData = jsonDecode(response.body);
      String message = errorData['detail'] ?? "Hardware Binding Failed";
      throw Exception(message);
    }
  }

  /// Gets the device's current location. Returns null if permission denied or unavailable.
  Future<Map<String, dynamic>?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // Reverse geocode to get city/country
      String city = '';
      String country = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          city = placemarks[0].locality ?? '';
          country = placemarks[0].country ?? '';
        }
      } catch (_) {}

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': city,
        'country': country,
      };
    } catch (e) {
      debugPrint("🏛️ Location fetch failed (non-critical): $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> initializeRole({
    required String token,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/institution/initialize-role'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'role': role}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      if (data['role_id'] != null) data['role_id'] = data['role_id'].toString();
      return data;
    }

    throw Exception(data['detail'] ?? "Role initialization failed.");
  }

  Future<Map<String, dynamic>> createIdentity({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/profile/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) return data;

    throw Exception(data['detail'] ?? "Failed to create identity.");
  }

  Future<Map<String, dynamic>> syncIdentity({required String token, required String deviceId}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/sync-identity_confirmation'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"device_id": deviceId}),
    );
    return jsonDecode(response.body);
  }

  Future<String?> _getHardwareId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      debugPrint("🏛️ Engine: Hardware ID Fetch Failed: $e");
    }
    return null;
  }

  Future<String?> performSilentRecovery() async {
    try {
      final String? masterKey = await StarlightSecureVault.getMasterKey();
      final String? deviceId = await StarlightSecureVault.getDeviceId();

      if (masterKey == null || deviceId == null) {
        debugPrint("🏛️ Engine: Hardware keys missing from Vault. Manual entry required.");
        return null;
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String payload = "$deviceId|$timestamp";

      var keyBytes = utf8.encode(masterKey);
      var dataBytes = utf8.encode(payload);
      var hmac = Hmac(sha256, keyBytes);
      var signature = hmac.convert(dataBytes);

      debugPrint("🏛️ Engine: Attempting Hardware Handshake for $deviceId");

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/silent-recovery'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'signature': signature.toString(),
          'payload': payload,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['secondary_verification_required'] == true) {
        return null;
      }

      if (response.statusCode == 200 && data['access_token'] != null) {
        final String freshToken = data['access_token'];
        final String roleId = data['role_id'].toString();

        await StarlightStorage.saveUserSession(freshToken, roleId);

        if (data['role'] != null) {
          await StarlightStorage.setUserRole(data['role']);
        }

        debugPrint("🏛️ Engine: Hardware Authenticated. Fresh JWT Synchronized.");
        return freshToken;
      } else {
        debugPrint("🏛️ Engine: Recovery Rejected by Server: ${data['detail'] ?? 'Unauthorized'}");
        return null;
      }
    } catch (e) {
      debugPrint("🏛️ Engine: Fatal Recovery Error: ${e.toString()}");
      return null;
    }
  }
}
