import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' show debugPrint;
import '../../../core/sign.dart'; // Using your Red/Green Sign Box Engine
import '../../../core/storage.dart';
import '../../../l10n/strings.dart';
import '../../../services/auth/firebase_phone_service.dart';
import 'chat_list_screen.dart';

class OwnerChatVerificationScreen extends StatefulWidget {
  const OwnerChatVerificationScreen({super.key});

  @override
  State<OwnerChatVerificationScreen> createState() => _OwnerChatVerificationScreenState();
}

class _OwnerChatVerificationScreenState extends State<OwnerChatVerificationScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  bool _firebaseInitialized = false;
  bool _isCheckingVerification = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _checkExistingVerification();
  }

  Future<void> _checkExistingVerification() async {
    // Prevent multiple simultaneous checks
    if (_isCheckingVerification) return;
    _isCheckingVerification = true;

    // Check local chat verification first (same key used by hub and chat list)
    final isVerified = await StarlightStorage.isChatVerified();
    if (isVerified && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatListScreen()),
      );
      return;
    }

    // Check server verification status
    try {
      final serverVerified = await FirebasePhoneService.checkServerVerificationStatus();
      if (serverVerified && mounted) {
        await StarlightStorage.setChatVerified(true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatListScreen()),
        );
      }
    } catch (e) {
      // Silently fail, let user verify manually
      debugPrint('Error checking verification: $e');
    }
  }

  Future<void> _initializeFirebase() async {
    // Prevent re-initialization
    if (_firebaseInitialized) return;

    try {
      await FirebasePhoneService.initialize();
      if (mounted) {
        setState(() => _firebaseInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, tr('firebaseInitFailed', {'error': '$e'}));
      }
    }
  }

  Future<void> _sendOTP() async {
    // 1. Hide keyboard immediately to prevent UI lag shown in your logs
    FocusScope.of(context).unfocus();

    String rawInput = _phoneController.text.trim();

    // 2. Basic validation - just check we have enough digits
    String digitsOnly = rawInput.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length < 10) {
      StarlightUtils.showErrorBox(context, tr('enterCompleteMobile'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint("Attempting OTP for: $rawInput");

      // Service handles all normalization
      bool success = await FirebasePhoneService.sendOTPToPakistan(rawInput);

      if (success) {
        setState(() => _otpSent = true);
        StarlightUtils.showSuccessBox(context, tr('otpSentSuccess'));
      } else {
        StarlightUtils.showErrorBox(context, tr('serviceFailedInternet'));
      }
    } catch (e) {
      // This catches "App Not Verified" or "SMS Quota Exhausted"
      StarlightUtils.showErrorBox(context, tr('firebaseError', {'error': '$e'}));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      StarlightUtils.showErrorBox(context, tr('enter6DigitOtp'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First verify with Firebase
      bool firebaseSuccess = await FirebasePhoneService.verifyOTP(_otpController.text);
      
      if (firebaseSuccess) {
        final user = FirebasePhoneService.currentUser;
        if (user != null) {
          // Send verification to server
          bool serverSuccess = await FirebasePhoneService.verifyWithServer(
            user.phoneNumber ?? '',
            "AdrTqXGxJBtiH_SazUCF-6eF2s_RwaRqVnBOu8UU0GO9qMRSYnErZrmntemHiZrf_zoX0VBipVUOw0TtaZxGe6weG5WMJO5Tz7FLCq5vVyocgQ2tPwVUvIiWcEbqd_HwaVsCZYPKQBl0DxF7UQzTVfsJbQ",
            user.uid,
          );
          
          if (serverSuccess) {
            // Store Firebase user info
            await StarlightStorage.setFirebaseUserId(user.uid);
            await StarlightStorage.setVerifiedPhone(user.phoneNumber ?? '');
            await StarlightStorage.setChatVerified(true); // Main flag used by hub/chat list
            await StarlightStorage.setUserPhoneNumber(user.phoneNumber ?? '');
            await StarlightStorage.setFirebaseToken(FirebasePhoneService.apiToken);

            if (mounted) {
              StarlightUtils.showSuccessBox(context, tr('phoneVerifiedGranted'));
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen())
              );
            }
          } else {
            StarlightUtils.showErrorBox(context, tr('serverVerificationFailed'));
            // Sign out from Firebase if server verification fails
            await FirebasePhoneService.signOut();
          }
        } else {
          StarlightUtils.showErrorBox(context, tr('firebaseUserNotFound'));
        }
      } else {
        StarlightUtils.showErrorBox(context, tr('invalidOtpTryAgain'));
      }
    } catch (e) {
      StarlightUtils.showErrorBox(context, tr('otpVerificationFailed', {'error': '$e'}));
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0, 
        backgroundColor: Colors.white, 
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(tr('ownerChatGateway'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr('ownerChat'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF263238))),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Text(
                    "🇵🇰 PK",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _otpSent
                  ? tr('enterCodeSent')
                  : tr('verifyOwnerChat'),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            if (!_firebaseInitialized)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('initializingFirebase'),
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),

            // Phone / OTP Input Field
            TextField(
              controller: _otpSent ? _otpController : _phoneController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
              inputFormatters: [
                _otpSent 
                  ? FilteringTextInputFormatter.digitsOnly
                  : FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
              ],
              maxLength: _otpSent ? 6 : 11,
              decoration: InputDecoration(
                prefixIcon: Icon(_otpSent ? Icons.lock_outline : Icons.phone_android_rounded, color: Color(0xFF263238)),
                prefixText: _otpSent ? "" : "+92 ",
                prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
                hintText: _otpSent ? "123456" : "0XXX XXXXXXX",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                counterText: "",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Color(0xFF263238), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
              ),
            ),
            const SizedBox(height: 25),

            // High-End Action Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_isLoading || !_firebaseInitialized) ? null : (_otpSent ? _verifyOTP : _sendOTP),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF263238),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(tr('processing'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_otpSent ? Icons.verified_user : Icons.send_to_mobile),
                          const SizedBox(width: 8),
                          Text(
                            _otpSent ? tr('verifyPakistanNumber') : tr('sendOtpToPakistan'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
            
            if (_otpSent)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: TextButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _otpSent = false;
                      _otpController.clear();
                    });
                  },
                  child: Text(
                    tr('changePhoneNumber'),
                    style: const TextStyle(color: Color(0xFF263238)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
