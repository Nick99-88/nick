import 'dart:async';
import 'package:flutter/material.dart';
import 'package:starlight_flutter/screens/auth/reset_password_screen.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth/auth_service.dart';
import 'login_screen.dart';
import '../../l10n/strings.dart';
// import 'reset_password_screen.dart'; // 🏛️ Import your future Reset Password screen

class OTPScreen extends StatefulWidget {
  final String email;
  final String action;

  const OTPScreen({super.key, required this.email, required this.action});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final AuthService _authService = AuthService();

  int _resendTimer = 60;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    if (_timer != null) _timer!.cancel();
    _resendTimer = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer == 0) {
        setState(() => timer.cancel());
      } else {
        setState(() => _resendTimer--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onVerify() async {
    String otp = _controllers.map((e) => e.text).join();
    if (otp.length < 6) {
      StarlightUtils.showErrorBox(context, tr('enterFullSixDigitCode'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.verifyOTP(widget.email, otp, widget.action);

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, result['message']);

        // 🏛️ DUAL-NAVIGATION LOGIC
        if (widget.action == "signup_verification") {
          // 1. Signup Flow -> Go to Login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
          );
          // Inside _onVerify in OTPScreen
        } else if (widget.action == "recovery") {
          // 🏛️ Identity verified, move to final reset phase
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(email: widget.email),
            ),
          );


          // Temporary placeholder until ResetPasswordScreen is ready
          StarlightUtils.showSuccessBox(context, tr('identityVerifiedSetPassword'));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  void _onResend() async {
    if (_resendTimer > 0) return;
    try {
      final result = await _authService.resendOTP(widget.email);
      StarlightUtils.showSuccessBox(context, result['message']);
      _startTimer();
    } catch (e) {
      StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: StarlightTheme.primaryBlue)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 80, color: StarlightTheme.primaryBlue),
            const SizedBox(height: 24),
            Text(
              widget.action == "recovery" ? tr('securityRecovery') : tr('verifyIdentity'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(tr('codeSentTo', {'email': widget.email}), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('editEmail'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) => _buildOTPBox(index)),
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isLoading ? null : _onVerify,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.action == "recovery" ? tr('verifyRecoveryButton') : tr('verifyActivateButton')),
            ),

            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: _resendTimer == 0 ? _onResend : null,
                child: Text(
                  _resendTimer == 0
                      ? tr('resendOtpCode')
                      : tr('resendIn', {'seconds': '$_resendTimer'}),
                  style: TextStyle(color: _resendTimer == 0 ? StarlightTheme.primaryBlue : Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOTPBox(int index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: StarlightTheme.primaryBlue, width: 2)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }
}