import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/identity_controller.dart';
import '../../core/storage.dart';
import '../../services/api_service.dart';
import '../../services/auth/firebase_phone_service.dart';
import 'signup_screen.dart';
import 'support_screen.dart';
import 'forgot_password_screen.dart';
import 'qr_login_display.dart';
import 'identity_screen.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth/auth_service.dart';
import '../../core/platform_gate.dart';
import '../../core/router_gateway.dart';
import '../../chat_system/whatsapp_chat.dart';
import '../../widgets/intro_widgets/onboarding_overlay.dart';
import '../../l10n/strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Tabs & Options
  String _activeTab = "EMAIL"; // "EMAIL" or "PHONE"
  String _emailMode = "PASSWORD"; // "PASSWORD" or "OTP"
  String _phoneMode = "PASSWORD"; // "PASSWORD" or "OTP" (or "SIGNUP")

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailOtpController = TextEditingController();

  final _phoneController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  final _phoneConfirmPasswordController = TextEditingController();
  final _phoneNameController = TextEditingController();
  final _phoneOtpController = TextEditingController();

  late final AuthService _authService = AuthService();

  // Loading & Flow state
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _agreedToTerms = false;

  bool _isEmailOtpSent = false;
  bool _isEmailResending = false;
  bool _isPhoneOtpSent = false;
  bool _isPhoneChecked = false;
  bool _phoneAccountExists = false;

  String _verificationId = "";

  static const String privacyPolicyUrl = 'https://starlight.app/privacy-policy';
  static const String termsConditionsUrl = 'https://starlight.app/terms-conditions';

  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await StarlightStorage.isOnboardingCompleted();
    if (mounted) {
      setState(() => _showOnboarding = !completed);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailOtpController.dispose();
    _phoneController.dispose();
    _phonePasswordController.dispose();
    _phoneConfirmPasswordController.dispose();
    _phoneNameController.dispose();
    _phoneOtpController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // --- 🏛️ MULTI-METHOD LOGIN SUBMISSION HANDLERS ---

  Future<void> _handleEmailPasswordLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      StarlightUtils.showErrorBox(context, tr('fillEmailCredentials'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final loginData = await _authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await _processServerHandshake(loginData);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, tr('hardwareVaultSecured'));
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handleEmailSendOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      StarlightUtils.showErrorBox(context, tr('enterValidEmailOtp'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final res = await ApiService.post('/auth/email-login-send-otp', {'email': email}, requireAuth: false);
      setState(() {
        _isEmailOtpSent = true;
        _isLoading = false;
      });
      if (mounted) {
        StarlightUtils.showSuccessBox(context, res['message'] ?? tr('loginOtpSent'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handleResendEmailOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains("@")) return;
    setState(() => _isEmailResending = true);

    try {
      final res = await ApiService.post('/auth/email-login-send-otp', {'email': email}, requireAuth: false);
      if (mounted) {
        StarlightUtils.showSuccessBox(context, res['message'] ?? tr('otpResent'));
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    } finally {
      if (mounted) setState(() => _isEmailResending = false);
    }
  }

  Future<void> _handleEmailVerifyOTP() async {
    final email = _emailController.text.trim();
    final otp = _emailOtpController.text.trim();
    if (otp.length != 6) {
      StarlightUtils.showErrorBox(context, tr('fullSixDigitVerification'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final activeAppId = await StarlightStorage.getAppId() ?? "starlight";
      final String deviceId = await PlatformGate.getDeviceId();
      final String deviceName = await PlatformGate.getDeviceName();
      final loginData = await ApiService.post('/auth/email-login-verify-otp', {
        'email': email,
        'otp': otp,
        'app_id': activeAppId,
        'device_id': deviceId,
        'device_name': deviceName,
      }, requireAuth: false);

      await _processServerHandshake(loginData);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, tr('emailOtpHandshakeVerified'));
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handlePhoneCheck() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      StarlightUtils.showErrorBox(context, tr('validTenDigitPhone'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final formatted = "+92$phone";
      final checkRes = await ApiService.post('/auth/phone-check', {'phone_number': formatted}, requireAuth: false);
      final bool exists = checkRes['exists'] ?? false;

      setState(() {
        _phoneAccountExists = exists;
        _isPhoneChecked = true;
        _phoneMode = exists ? "PASSWORD" : "SIGNUP";
        _isLoading = false;
      });

      if (!exists) {
        StarlightUtils.showSuccessBox(context, tr('newPhoneNumberOtp'));
        await _sendPhoneOTP(); // Auto send OTP for new users
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _sendPhoneOTP() async {
    final phone = _phoneController.text.trim();
    final formatted = "+92$phone";
    setState(() => _isLoading = true);

    try {
      await FirebasePhoneService.initialize();
      
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formatted,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          setState(() {
            _isPhoneOtpSent = true;
            _isLoading = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          StarlightUtils.showErrorBox(context, e.message ?? "Firebase verification failed");
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isPhoneOtpSent = true;
            _isLoading = false;
          });
          StarlightUtils.showSuccessBox(context, tr('smsOtpDispatched'));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      StarlightUtils.showErrorBox(context, tr('couldNotSendOtp'));
    }
  }

  Future<void> _handlePhonePasswordLogin() async {
    final phone = _phoneController.text.trim();
    final password = _phonePasswordController.text;
    if (password.isEmpty) {
      StarlightUtils.showErrorBox(context, tr('passwordRequired'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final formatted = "+92$phone";
      final activeAppId = await StarlightStorage.getAppId() ?? "starlight";
      final String deviceId = await PlatformGate.getDeviceId();
      final String deviceName = await PlatformGate.getDeviceName();
      final loginData = await ApiService.post('/auth/phone-login-password', {
        'phone_number': formatted,
        'password': password,
        'app_id': activeAppId,
        'device_id': deviceId,
        'device_name': deviceName,
      }, requireAuth: false);

      await _processServerHandshake(loginData);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, tr('phoneCredentialsVerified'));
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handlePhoneVerifyOTPAndLogin() async {
    final otp = _phoneOtpController.text.trim();
    final phone = _phoneController.text.trim();
    final formatted = "+92$phone";
    if (otp.length != 6) {
      StarlightUtils.showErrorBox(context, tr('fullSixDigitSmsOtp'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Successfully verified with Firebase! Now trigger login handshake with server
      final activeAppId = await StarlightStorage.getAppId() ?? "starlight";
      final String deviceId = await PlatformGate.getDeviceId();
      final String deviceName = await PlatformGate.getDeviceName();
      final loginData = await ApiService.post('/auth/phone-login-otp', {
        'phone_number': formatted,
        'app_id': activeAppId,
        'device_id': deviceId,
        'device_name': deviceName,
      }, requireAuth: false);

      // Save phone states locally
      await StarlightStorage.setUserPhoneNumber(formatted);
      await StarlightStorage.setVerifiedPhone(formatted);
      await StarlightStorage.setPhoneVerified(true);
      await StarlightStorage.setChatVerified(true);

      await _processServerHandshake(loginData);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, tr('otpVerifiedSuccessfully'));
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handlePhoneVerifyOTPAndRegister() async {
    final otp = _phoneOtpController.text.trim();
    final phone = _phoneController.text.trim();
    final formatted = "+92$phone";
    final name = _phoneNameController.text.trim();
    final password = _phonePasswordController.text;
    final confirmPassword = _phoneConfirmPasswordController.text;

    if (otp.length != 6) {
      StarlightUtils.showErrorBox(context, tr('fullSixDigitSmsOtp'));
      return;
    }
    if (name.isEmpty) {
      StarlightUtils.showErrorBox(context, tr('fullNameRequired'));
      return;
    }
    if (password.isEmpty || password.length < 6) {
      StarlightUtils.showErrorBox(context, tr('passwordMin'));
      return;
    }
    if (password != confirmPassword) {
      StarlightUtils.showErrorBox(context, tr('passwordsDoNotMatch'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verify with Firebase
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // 2. Submit Sign Up details to server
      final activeAppId = await StarlightStorage.getAppId() ?? "starlight";
      final deviceId = await PlatformGate.getDeviceId();

      final loginData = await ApiService.post('/auth/phone-signup', {
        'phone_number': formatted,
        'name': name,
        'password': password,
        'app_id': activeAppId,
        'device_id': deviceId,
      }, requireAuth: false);

      // Save locally
      await StarlightStorage.setUserPhoneNumber(formatted);
      await StarlightStorage.setVerifiedPhone(formatted);
      await StarlightStorage.setPhoneVerified(true);
      await StarlightStorage.setChatVerified(true);

      await _processServerHandshake(loginData);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, tr('accountCreatedPhone'));
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  // --- 🏛️ GOOGLE LOGIN ---

  Future<void> _handleGoogleLogin() async {
    if (_showOnboarding) {
      await StarlightStorage.setOnboardingCompleted();
      if (mounted) setState(() => _showOnboarding = false);
    }

    if (!_agreedToTerms) {
      StarlightUtils.showErrorBox(context, tr('agreePrivacyTerms'));
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final loginData = await _authService.signInWithGoogleUnified();
      await _processServerHandshake(loginData);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, tr('googleVaultSecured'));
        await UniversalRouter.routeUser(context);
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString().replaceAll("Exception: ", "");
        if (!errorMsg.contains("Sign-in aborted")) {
           StarlightUtils.showErrorBox(context, tr('googleSignInFailed') + errorMsg);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, tr('unexpectedError') + e.toString());
      }
    }
  }

  // --- 🏛️ UNIVERSAL LOGIN ACTION ROUTER ---

  Future<void> _submitLoginAction() async {
    if (!_agreedToTerms) {
      StarlightUtils.showErrorBox(context, tr('agreePrivacyTerms'));
      return;
    }

    if (_activeTab == "EMAIL") {
      if (_emailMode == "PASSWORD") {
        await _handleEmailPasswordLogin();
      } else {
        if (!_isEmailOtpSent) {
          await _handleEmailSendOTP();
        } else {
          await _handleEmailVerifyOTP();
        }
      }
    } else {
      // PHONE TAB
      if (!_isPhoneChecked) {
        await _handlePhoneCheck();
      } else {
        if (_phoneAccountExists) {
          if (_phoneMode == "PASSWORD") {
            await _handlePhonePasswordLogin();
          } else {
            // Phone OTP Login
            if (!_isPhoneOtpSent) {
              await _sendPhoneOTP();
            } else {
              await _handlePhoneVerifyOTPAndLogin();
            }
          }
        } else {
          // Phone Signup/Registration
          if (!_isPhoneOtpSent) {
            await _sendPhoneOTP();
          } else {
            await _handlePhoneVerifyOTPAndRegister();
          }
        }
      }
    }
  }

  Future<void> _processServerHandshake(Map<String, dynamic> loginData) async {
    if (loginData['secondary_verification_required'] == true) {
      final String phoneHint = loginData['phone_hint'] ?? "";
      final String userId = loginData['user_id'] ?? "";
      
      // Stop standard handshake, initiate challenge flow!
      await _launchSecondaryVerificationChallenge(phoneHint, userId);
      return;
    }

    final String token = loginData['access_token'];
    final String role = loginData['role'] ?? 'user';
    final bool hasIdentity = loginData['identity'] ?? false;
    final bool isProfileComplete = loginData['data_identifier'] ?? false;
    final String roleId = loginData['role_id']?.toString() ?? "0";
    final String? instToken = loginData['institution_id']?.toString();
    final String otkSeed = loginData['otk'] ?? "";
    final Map<String, dynamic> userData = loginData['user_data'] ?? {};

    final String deviceId = await PlatformGate.getDeviceId();
    await _authService.finalizeLink(token: token, deviceId: deviceId, seed: otkSeed);

    await StarlightStorage.saveUserSession(token, roleId);
    await StarlightStorage.setUserRole(role);
    await StarlightStorage.setIdentity(hasIdentity);
    if (isProfileComplete) {
      await StarlightStorage.setIdentityVerifyToken("IDENTITY_LOCKED");
    } else {
      await StarlightStorage.setIdentityVerifyToken("");
    }
    if (instToken != null && instToken.isNotEmpty) {
      await StarlightStorage.setInstitutionalToken(instToken);
      if (role == 'owner') {
        await StarlightStorage.setOwnerVerifyToken("OWNERSHIP_VERIFIED");
      }
    }

    if (userData.isNotEmpty) {
      await IdentityController.setFullIdentity(userData);
    }
  }

  Future<void> _launchSecondaryVerificationChallenge(String phoneHint, String userId) async {
    final TextEditingController otpCtrl = TextEditingController();
    final TextEditingController confirmPhoneCtrl = TextEditingController();
    bool isOTPSent = false;
    bool isVerifying = false;
    String errorMessage = "";
    String verificationId = "";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.shield_rounded, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    tr('mfaVerification'),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isOTPSent
                        ? tr('mfaVerifyOtpPrefix') + phoneHint + "."
                        : tr('secondaryVerificationPrefix') + phoneHint + ".",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  if (!isOTPSent) ...[
                    TextField(
                      controller: confirmPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: tr('confirmCompletePhone'),
                        labelStyle: TextStyle(color: Colors.white38),
                        prefixText: "+92 ",
                        prefixStyle: TextStyle(color: Colors.white70, fontSize: 13),
                        counterText: "",
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 8, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: "000000",
                        hintStyle: TextStyle(color: Colors.white24),
                        counterText: "",
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                      ),
                    ),
                  ],
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _isLoading = false);
                    Navigator.pop(context);
                  },
                  child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          setDialogState(() {
                            isVerifying = true;
                            errorMessage = "";
                          });

                          try {
                            final num = confirmPhoneCtrl.text.trim();
                            if (num.length != 10) {
                               throw Exception(tr('enterValidTenDigit'));
                            }
                            final completePhone = "+92$num";
                            final lastThreeDigits = phoneHint.replaceAll(".", "").trim();
                            if (!completePhone.endsWith(lastThreeDigits)) {
                               throw Exception(tr('phoneMismatchPrefix') + lastThreeDigits + ".");
                            }

                            if (!isOTPSent) {
                              await FirebasePhoneService.initialize();
                              await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: completePhone,
                                verificationCompleted: (PhoneAuthCredential credential) async {
                                  await FirebaseAuth.instance.signInWithCredential(credential);
                                  setDialogState(() {
                                    isOTPSent = true;
                                    isVerifying = false;
                                  });
                                },
                                verificationFailed: (FirebaseAuthException e) {
                                  setDialogState(() {
                                     errorMessage = e.message ?? tr('firebaseSmsDispatchFailed');
                                    isVerifying = false;
                                  });
                                },
                                codeSent: (String vid, int? resendToken) {
                                  verificationId = vid;
                                  setDialogState(() {
                                    isOTPSent = true;
                                    isVerifying = false;
                                  });
                                },
                                codeAutoRetrievalTimeout: (String vid) {
                                  verificationId = vid;
                                },
                              );
                            } else {
                              final otpCode = otpCtrl.text.trim();
                              if (otpCode.length != 6) {
                                 throw Exception(tr('enterFullSixDigit'));
                              }
                              final credential = PhoneAuthProvider.credential(
                                verificationId: verificationId,
                                smsCode: otpCode,
                              );
                              await FirebaseAuth.instance.signInWithCredential(credential);

                              // Verified with Firebase! Now finalize and register hardware ID
                              final activeAppId = await StarlightStorage.getAppId() ?? "starlight";
                              final String deviceId = await PlatformGate.getDeviceId();
                              final String deviceName = await PlatformGate.getDeviceName();
                              
                              final finalizedHandshake = await ApiService.post(
                                '/auth/secondary-verification/finalize',
                                {
                                  'user_id': userId,
                                  'device_id': deviceId,
                                  'device_name': deviceName,
                                  'app_id': activeAppId,
                                  'phone_number': completePhone,
                                },
                                requireAuth: false,
                              );

                              // Success! Continue server handshake with the finalized login data
                              Navigator.pop(context); // Close OTP Dialog
                              
                              await _processServerHandshake(finalizedHandshake);
                              
                              if (mounted) {
                                 StarlightUtils.showSuccessBox(context, tr('identityVerifiedHardware'));
                                await UniversalRouter.routeUser(context);
                              }
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorMessage = e.toString().replaceAll("Exception: ", "");
                              isVerifying = false;
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                      : Text(
                          isOTPSent ? tr('verifyCode') : tr('sendOtp'),
                          style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleQRScan() async {
    if (!_agreedToTerms) {
      StarlightUtils.showErrorBox(context, tr('agreePrivacyTerms'));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QRLoginScannerView(
          onScan: (scannedToken) async {
            Navigator.pop(context); // Pop Scanner screen

            if (scannedToken.isEmpty) {
              StarlightUtils.showErrorBox(context, tr('invalidQrScanned'));
              return;
            }

            setState(() => _isLoading = true);

            try {
              final String deviceId = await PlatformGate.getDeviceId();
              final String deviceName = await PlatformGate.getDeviceName();

              Map<String, dynamic> loginData;

              // Try transfer endpoint first (server checks Redis for qr_token)
              try {
                loginData = await ApiService.post('/auth/qr/transfer', {
                  'qr_token': scannedToken,
                  'hardware_id': deviceId,
                  'device_name': deviceName,
                }, requireAuth: false);
              } catch (_) {
                // Not a transfer token — fall back to standard QR login
                final activeAppId = await StarlightStorage.getAppId() ?? "starlight";
                loginData = await ApiService.post('/auth/qr/authenticate', {
                  'qr_token': scannedToken,
                  'device_id': deviceId,
                  'device_name': deviceName,
                  'app_id': activeAppId,
                }, requireAuth: false);
              }

              await _processServerHandshake(loginData);

              if (mounted) {
                setState(() => _isLoading = false);
                StarlightUtils.showSuccessBox(context, tr('qrAuthVerified'));
                await UniversalRouter.routeUser(context);
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isLoading = false);
                StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
              }
            }
          },
        ),
      ),
    );
  }
  void _handleRecovery() => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()));
  void _handleHelp() => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen()));
  void _handleSignup() => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));

  void _showSubmitReportDialog() {
    final emailCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.feedback_outlined, color: Colors.orangeAccent),
              SizedBox(width: 10),
              Text(tr('submitReportComplaint'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('encounterProblem'),
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: tr('yourEmailAddress'),
                      labelStyle: TextStyle(color: Colors.white38, fontSize: 11),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                    ),
                    validator: (v) {
                       if (v == null || v.trim().isEmpty) return tr('emailRequired');
                       if (!v.contains("@")) return tr('enterValidEmail');
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: detailCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: tr('problemDetails'),
                      labelStyle: TextStyle(color: Colors.white38, fontSize: 11),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                    ),
                     validator: (v) => v == null || v.trim().isEmpty ? tr('detailsRequired') : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: loading ? null : () async {
                if (formKey.currentState!.validate()) {
                  setDialogState(() => loading = true);
                  try {
                    final res = await ApiService.post('/complains', {
                      'email': emailCtrl.text.trim(),
                      'detail': detailCtrl.text.trim(),
                    });
                    if (res['status'] == 'success') {
                      Navigator.pop(context);
                      StarlightUtils.showSuccessBox(context, tr('complaintSubmitted'));
                    } else {
                       StarlightUtils.showErrorBox(context, tr('failedToSubmit') + (res['message'] ?? 'Error').toString());
                    }
                  } catch (e) {
                    StarlightUtils.showErrorBox(context, tr('submissionError') + e.toString());
                  } finally {
                    setDialogState(() => loading = false);
                  }
                }
              },
              child: loading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(tr('submit'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChatOnlyLogin() async {
    final token = await StarlightStorage.getUserToken();
    if (token == null) {
      StarlightUtils.showErrorBox(context, tr('pleaseLoginFirst'));
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WhatsAppChatEntry()),
      );
    }
  }

  void _resetPhoneFlow() {
    setState(() {
      _isPhoneChecked = false;
      _isPhoneOtpSent = false;
      _phoneAccountExists = false;
      _phoneOtpController.clear();
      _phonePasswordController.clear();
      _phoneConfirmPasswordController.clear();
      _phoneNameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
              const Icon(Icons.security, size: 70, color: StarlightTheme.primaryBlue),
              const SizedBox(height: 12),
              Text(
                tr('starlightConsole'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
              ),
              Text(
                tr('accessSecureVault'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // --- 🏛️ TAB CONTROLLER ---
              Row(
                children: [
                  Expanded(child: _buildTabButton("EMAIL")),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTabButton("PHONE")),
                ],
              ),
              const SizedBox(height: 24),

              // --- 🏛️ FORM FIELDS ACCORDING TO THE ACTIVE TAB ---
              if (_activeTab == "EMAIL") ...[
                _buildEmailSubOptions(),
                const SizedBox(height: 16),
                _buildEmailForm(),
              ] else ...[
                _buildPhoneForm(),
              ],

              const SizedBox(height: 16),

              // Privacy Policy & Terms Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreedToTerms,
                    onChanged: (value) {
                      setState(() => _agreedToTerms = value ?? false);
                    },
                    activeColor: StarlightTheme.primaryBlue,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: tr('agreeTo'),
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            TextSpan(
                              text: tr('privacyPolicy'),
                              style: const TextStyle(
                                color: StarlightTheme.primaryBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(privacyPolicyUrl),
                            ),
                            TextSpan(
                              text: tr('and'),
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            TextSpan(
                              text: tr('termsConditions'),
                              style: const TextStyle(
                                color: StarlightTheme.primaryBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(termsConditionsUrl),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitLoginAction,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_getSubmitButtonText(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 24),
              Center(child: Text(tr('or'), style: const TextStyle(color: Colors.grey))),
              const SizedBox(height: 24),

              OutlinedButton.icon(
                icon: const Icon(Icons.g_mobiledata, size: 30),
                label: Text(tr('loginWithGoogle')),
                onPressed: _isLoading ? null : _handleGoogleLogin,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2),
                label: Text(tr('showQrCodeToLogin')),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QRLoginDisplayScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(tr('newToStarlight')),
                  TextButton(
                    onPressed: _handleSignup,
                    child: Text(tr('joinInstitution'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              TextButton.icon(
                onPressed: _handleHelp,
                icon: const Icon(Icons.help_outline, size: 16),
                label: Text(tr('supportHelp')),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () async {
                  await StarlightStorage.clearAppIdentity();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const IdentityScreen()),
                    );
                  }
                },
                icon: const Icon(Icons.apps_rounded, size: 16),
                label: Text(tr('switchAppIdentity')),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _showSubmitReportDialog,
                icon: const Icon(Icons.feedback_outlined, size: 16, color: Colors.orangeAccent),
                label: Text(tr('submitComplaint'), style: const TextStyle(color: Colors.orangeAccent)),
              ),
            ],
          ),
        ),
      ),
        ),
      if (_showOnboarding) OnboardingOverlay(
        isLoginMode: true,
        onDismiss: () => setState(() => _showOnboarding = false),
      ),
    ],
    );
  }

  Widget _buildTabButton(String label) {
    final bool isActive = _activeTab == label;
    final display = label == "EMAIL" ? tr('tabEmail') : tr('tabPhone');
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = label;
          _isLoading = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? StarlightTheme.primaryBlue : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? StarlightTheme.primaryBlue : Colors.grey.withOpacity(0.2)),
        ),
        child: Text(
          display,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSubOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildChoiceChip("PASSWORD", tr('usePassword'), _emailMode == "PASSWORD", (val) {
          if (val) setState(() => _emailMode = "PASSWORD");
        }),
        const SizedBox(width: 12),
        _buildChoiceChip("OTP", tr('useOtpEmail'), _emailMode == "OTP", (val) {
          if (val) setState(() => _emailMode = "OTP");
        }),
      ],
    );
  }

  Widget _buildChoiceChip(String val, String label, bool isSelected, Function(bool) onSelected) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 11, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: StarlightTheme.primaryBlue,
      backgroundColor: Colors.grey.withOpacity(0.1),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          decoration: InputDecoration(
            labelText: tr('emailAddress'),
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        if (_emailMode == "PASSWORD") ...[
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            decoration: InputDecoration(
              labelText: tr('password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleRecovery,
              child: Text(tr('forgotPassword')),
            ),
          ),
        ] else ...[
          if (_isEmailOtpSent) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _emailOtpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 8, fontSize: 16),
              decoration: InputDecoration(
                labelText: tr('emailOtpCode'),
                prefixIcon: Icon(Icons.mark_email_read_rounded),
                counterText: "",
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isEmailResending ? null : _handleResendEmailOTP,
                icon: _isEmailResending
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 16),
                label: Text(_isEmailResending ? tr('resending') : tr('resendOtp')),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !_isPhoneChecked,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          decoration: InputDecoration(
            labelText: tr('phoneNumber'),
            prefixText: "+92 ",
            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
            prefixIcon: const Icon(Icons.phone_android_rounded),
            suffixIcon: _isPhoneChecked
                ? IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey, size: 18),
                    onPressed: _resetPhoneFlow,
                  )
                : null,
          ),
        ),
        if (_isPhoneChecked) ...[
          const SizedBox(height: 16),
          if (_phoneAccountExists) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChoiceChip("PASSWORD", tr('usePassword'), _phoneMode == "PASSWORD", (val) {
                  if (val) setState(() => _phoneMode = "PASSWORD");
                }),
                const SizedBox(width: 12),
                _buildChoiceChip("OTP", tr('useSmsOtp'), _phoneMode == "OTP", (val) {
                  if (val) setState(() => _phoneMode = "OTP");
                }),
              ],
            ),
            const SizedBox(height: 16),
            if (_phoneMode == "PASSWORD") ...[
              TextField(
                controller: _phonePasswordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                decoration: InputDecoration(
                  labelText: tr('accountPassword'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _handleRecovery,
              child: Text(tr('forgotPassword')),
                ),
              ),
            ]
            else ...[
              if (_isPhoneOtpSent)
                TextField(
                  controller: _phoneOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 8, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('smsOtpCode'),
                    prefixIcon: Icon(Icons.vibration_rounded),
                    counterText: "",
                  ),
                ),
            ],
          ] else ...[
            // Registration for non-existing Phone
            Text(
              tr('newPhoneRegister'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneNameController,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
                labelText: tr('fullName'),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phonePasswordController,
              obscureText: !_isPasswordVisible,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
              labelText: tr('password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneConfirmPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
                labelText: tr('confirmPassword'),
                prefixIcon: Icon(Icons.shield_outlined),
              ),
            ),
            const SizedBox(height: 16),
            if (_isPhoneOtpSent)
              TextField(
                controller: _phoneOtpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 8, fontSize: 16),
                decoration: InputDecoration(
                  labelText: tr('smsOtpCode'),
                  prefixIcon: Icon(Icons.vibration_rounded),
                  counterText: "",
                ),
              ),
          ],
        ],
      ],
    );
  }

  String _getSubmitButtonText() {
    if (_activeTab == "EMAIL") {
      if (_emailMode == "PASSWORD") return tr('loginButton');
      return _isEmailOtpSent ? tr('verifyLoginButton') : tr('sendOtpEmailButton');
    } else {
      if (!_isPhoneChecked) return tr('continueButton');
      if (_phoneAccountExists) {
        if (_phoneMode == "PASSWORD") return tr('loginWithPasswordButton');
        return _isPhoneOtpSent ? tr('verifyLoginButton') : tr('sendSmsOtpButton');
      } else {
        return _isPhoneOtpSent ? tr('registerLoginButton') : tr('sendRegisterOtpButton');
      }
    }
  }
}

class _QRLoginScannerView extends StatelessWidget {
  final Function(String) onScan;

  const _QRLoginScannerView({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final MobileScannerController controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('scanQrLogin'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: StarlightTheme.primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            controller.dispose();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  final String code = barcode.rawValue!;
                  controller.dispose();
                  onScan(code);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: StarlightTheme.primaryBlue, width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
