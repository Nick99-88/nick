import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';
import '../../services/auth/firebase_phone_service.dart';
import '../../services/auth/auth_service.dart';
import 'otp_screen.dart';
import '../../l10n/strings.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  String _activeTab = "EMAIL"; // "EMAIL" or "PHONE"

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneOtpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isPhoneOtpSent = false;
  bool _isPhoneVerified = false;
  String _verificationId = "";

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _phoneOtpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleEmailRecovery() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      StarlightUtils.showErrorBox(context, tr('enterValidInstitutionEmail'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.forgotPassword(email);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, result['message']);

        // REUSE OTP SCREEN: Pass 'recovery' as the action
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              email: email,
              action: "recovery",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handlePhoneSendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      StarlightUtils.showErrorBox(context, tr('validTenDigitPhone'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final formatted = "+92$phone";
      // 1. Check if the phone exists on the server
      final checkRes = await ApiService.post('/auth/phone-check', {'phone_number': formatted}, requireAuth: false);
      final bool exists = checkRes['exists'] ?? false;

      if (!exists) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, tr('phoneNotRegistered'));
        return;
      }

      // 2. Trigger Firebase SMS OTP
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
          StarlightUtils.showErrorBox(context, e.message ?? tr('firebaseSmsDispatchFailed'));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isPhoneOtpSent = true;
            _isLoading = false;
          });
          StarlightUtils.showSuccessBox(context, tr('recoveryOtpSent'));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handlePhoneVerifyOTP() async {
    final otp = _phoneOtpController.text.trim();
    if (otp.length != 6) {
      StarlightUtils.showErrorBox(context, tr('enterFullSixDigitSms'));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() {
        _isPhoneVerified = true;
        _isLoading = false;
      });
      StarlightUtils.showSuccessBox(context, tr('identityVerifiedSetPassword'));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, tr('invalidOtpTryAgain'));
      }
    }
  }

  Future<void> _handlePhoneResetPassword() async {
    final phone = _phoneController.text.trim();
    final password = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

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
      final formatted = "+92$phone";
      final res = await ApiService.post('/auth/phone-reset-password', {
        'phone_number': formatted,
        'new_password': password,
      }, requireAuth: false);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, res['message'] ?? tr('passwordResetSuccess'));
        Navigator.pop(context); // Go back to login
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: StarlightTheme.primaryBlue),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset_rounded, size: 70, color: StarlightTheme.primaryBlue),
              const SizedBox(height: 16),
              Text(
                tr('accountRecovery'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
              ),
              Text(
                tr('chooseRecoveryMethod'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // TAB SELECTOR
              Row(
                children: [
                  Expanded(child: _buildTabButton("EMAIL", tr('tabEmail'))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTabButton("PHONE", tr('tabPhone'))),
                ],
              ),
              const SizedBox(height: 32),

              if (_activeTab == "EMAIL") ..._buildEmailForm() else ..._buildPhoneForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String value, String label) {
    final bool isActive = _activeTab == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = value;
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
          label,
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

  List<Widget> _buildEmailForm() {
    return [
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: tr('institutionEmail'),
          prefixIcon: Icon(Icons.email_outlined),
        ),
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _handleEmailRecovery,
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(tr('sendRecoveryCode'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
  }

  List<Widget> _buildPhoneForm() {
    if (_isPhoneVerified) {
      // Step 3: Enter new password
      return [
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: tr('newPassword'),
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: tr('confirmPassword'),
            prefixIcon: Icon(Icons.shield_outlined),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handlePhoneResetPassword,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(tr('resetPasswordButton'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ];
    }

    if (_isPhoneOtpSent) {
      // Step 2: Enter SMS OTP code
      return [
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
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handlePhoneVerifyOTP,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(tr('verifyOtpButton'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ];
    }

    // Step 1: Input phone number to request OTP
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          decoration: InputDecoration(
            labelText: tr('phoneNumber'),
            prefixText: "+92 ",
            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
            prefixIcon: Icon(Icons.phone_android_rounded),
          ),
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _isLoading ? null : _handlePhoneSendOTP,
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(tr('sendOtpCodeButton'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
  }
}
