import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/storage.dart';
import '../../services/setup/setup_service.dart';
import '../../core/app_routes.dart';

class PhoneVerificationScreen extends StatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  String _verificationId = '';
  String _firebaseToken = 'AdrTqXEcWzn0Swmxq1bXxLFyliAiZXQ4TQV1ymr8iQv8GVpNfqN4uYELibBXUg6b2Z2WBiYVlcjh-LTpTnDMDnEay9VuZj75EIQpeQezeLCroTSq1RtM7ey_EptubYBSl6ZxgM8Z5-263GDxW78ZaXmKFA';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Format phone number
      String phoneNumber = _phoneController.text.trim();
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+91$phoneNumber'; // Default to India code
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          _showError('Verification failed: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
          _showSuccess('OTP sent to $phoneNumber');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to send OTP: $e');
    }
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );
      
      await _signInWithCredential(credential);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Invalid OTP: $e');
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      // Initialize Firebase with the provided token
      await FirebaseAuth.instance.signInWithCredential(credential);
      
      // Update backend with phone verification
      final setupService = SetupService();
      await setupService.updatePhoneVerification(_phoneController.text.trim());
      
      // Update local storage
      await StarlightStorage.setPhoneVerified(true);
      await StarlightStorage.setUserPhoneNumber(_phoneController.text.trim());
      
      setState(() => _isLoading = false);
      _showSuccess('Phone number verified successfully!');
      
      // Navigate to chat list
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.chatList,
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Sign in failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Phone Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Icon
              const Icon(
                Icons.phone_android,
                size: 80,
                color: Colors.blue,
              ),
              
              const SizedBox(height: 30),
              
              // Title
              Text(
                _otpSent ? 'Enter OTP' : 'Verify Your Phone',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 10),
              
              // Subtitle
              Text(
                _otpSent 
                    ? 'Enter the 6-digit code sent to your phone'
                    : 'We need to verify your phone number to enable chat features',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Phone Number Field (show only if OTP not sent)
              if (!_otpSent) ...[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter 10-digit number',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixText: '+91 ',
                    prefixStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF1E1E2E),
                  ),
                  validator: (value) {
                    if (value == null || value.length != 10) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Send OTP Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Send OTP',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
              
              // OTP Field (show only if OTP sent)
              if (_otpSent) ...[
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'OTP Code',
                    hintText: 'Enter 6-digit code',
                    labelStyle: TextStyle(color: Colors.white70),
                    hintStyle: TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF1E1E2E),
                  ),
                  validator: (value) {
                    if (value == null || value.length != 6) {
                      return 'Please enter a valid 6-digit OTP';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Verify OTP Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                
                const SizedBox(height: 20),
                
                // Resend OTP
                TextButton(
                  onPressed: _isLoading ? null : _sendOTP,
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
              
              const Spacer(),
              
              // Skip Option
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
