import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/core/storage.dart';
import 'package:starlight_flutter/services/auth/chat_access_service.dart';

class WhatsAppPhoneVerificationScreen extends StatefulWidget {
  final VoidCallback onVerified;

  const WhatsAppPhoneVerificationScreen({super.key, required this.onVerified});

  @override
  State<WhatsAppPhoneVerificationScreen> createState() => _WhatsAppPhoneVerificationScreenState();
}

class _WhatsAppPhoneVerificationScreenState extends State<WhatsAppPhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _otpSent = false;
  String _verificationId = '';
  String _fullPhoneNumber = '';

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      _showError('Enter a valid 10-digit phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      _fullPhoneNumber = '+92$phone';

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signIn(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          _showError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to send OTP');
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showError('Enter the full 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await _signIn(credential);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Invalid OTP. Please try again.');
    }
  }

  Future<void> _signIn(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);

      await StarlightStorage.setUserPhoneNumber(_fullPhoneNumber);
      await StarlightStorage.setVerifiedPhone(_fullPhoneNumber);
      await StarlightStorage.setPhoneVerified(true);
      await StarlightStorage.setChatVerified(true);

      if (mounted) {
        widget.onVerified();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Verification failed. Please try again.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: StarlightTheme.primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Verify Phone', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(Icons.chat_bubble_outline, size: 72, color: StarlightTheme.primaryBlue),
              const SizedBox(height: 24),
              Text(
                _otpSent ? 'Enter the Code' : 'Verify Your Phone Number',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Text(
                _otpSent
                    ? 'Enter the 6-digit code sent to $_fullPhoneNumber'
                    : 'Starlight will send an SMS to verify your phone number.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 40),

              if (!_otpSent) ..._buildPhoneInput(),
              if (_otpSent) ..._buildOTPInput(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPhoneInput() {
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        decoration: InputDecoration(
          hintText: '3XXXXXXXXX',
          labelText: 'Phone Number',
          prefixText: '+92 ',
          prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(fontSize: 18, letterSpacing: 2),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _sendOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: StarlightTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ];
  }

  List<Widget> _buildOTPInput() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(6, (index) {
          return SizedBox(
            width: 48,
            child: TextField(
              controller: _otpControllers[index],
              focusNode: _otpFocusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                if (value.isNotEmpty && index < 5) {
                  _otpFocusNodes[index + 1].requestFocus();
                } else if (value.isEmpty && index > 0) {
                  _otpFocusNodes[index - 1].requestFocus();
                }
              },
            ),
          );
        }),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _verifyOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: StarlightTheme.primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 16),
      TextButton(
        onPressed: _isLoading ? null : _sendOTP,
        child: Text('Resend Code', style: TextStyle(color: StarlightTheme.primaryBlue, fontWeight: FontWeight.w600)),
      ),
    ];
  }
}
