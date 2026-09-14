import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/storage.dart';
import '../../services/auth/firebase_phone_service.dart';
import 'local_chat_id_screen.dart';

class PhoneNumberVerificationScreen extends StatefulWidget {
  const PhoneNumberVerificationScreen({super.key});

  @override
  State<PhoneNumberVerificationScreen> createState() => _PhoneNumberVerificationScreenState();
}

class _PhoneNumberVerificationScreenState extends State<PhoneNumberVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = true;
  bool _isCheckingServer = false;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _checkExistingVerification();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingVerification() async {
    setState(() => _isLoading = true);

    // Check local storage first
    final verifiedPhone = await StarlightStorage.getVerifiedPhone();
    final isVerified = await StarlightStorage.getChatVerified();

    if (verifiedPhone != null && isVerified == true) {
      // Phone is verified locally, navigate to chat ID screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LocalChatIdScreen()),
        );
      }
      return;
    }

    // No local verification, check server
    setState(() => _isCheckingServer = true);
    try {
      final serverVerified = await FirebasePhoneService.checkServerVerificationStatus();
      if (serverVerified) {
        // Server has verified number, it's already saved in local storage by the service
        final serverPhone = await StarlightStorage.getVerifiedPhone();
        if (serverPhone != null && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LocalChatIdScreen()),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint("Error checking server verification: $e");
    }

    // No verification found locally or on server, show verification UI
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isCheckingServer = false;
      });
    }
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await FirebasePhoneService.sendOTPToPakistan(_phoneController.text.trim());
      
      if (success) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        _showSuccess('OTP sent successfully');
      } else {
        setState(() => _isLoading = false);
        _showError('Failed to send OTP');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to send OTP: $e');
    }
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await FirebasePhoneService.verifyOTP(_otpController.text.trim());
      
      if (success) {
        // Get the authenticated user's phone number
        final currentUser = FirebasePhoneService.currentUser;
        final phoneNumber = currentUser?.phoneNumber ?? _phoneController.text.trim();
        
        // Save to local storage
        await StarlightStorage.setVerifiedPhone(phoneNumber);
        await StarlightStorage.setChatVerified(true);
        
        // Verify with server
        final firebaseUid = currentUser?.uid ?? '';
        final firebaseToken = FirebasePhoneService.apiToken;
        await FirebasePhoneService.verifyWithServer(phoneNumber, firebaseToken, firebaseUid);
        
        setState(() => _isLoading = false);
        _showSuccess('Phone number verified successfully!');
        
        // Navigate to chat ID screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LocalChatIdScreen()),
          );
        }
      } else {
        setState(() => _isLoading = false);
        _showError('Invalid OTP');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Verification failed: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF263238),
        ),
        title: const Text(
          'Phone Verification',
          style: TextStyle(
            color: Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isCheckingServer ? 'Checking verification status...' : 'Loading...',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_android,
                          size: 64,
                          color: Colors.blue,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Title
                      Text(
                        _otpSent ? 'Enter OTP' : 'Verify Your Phone',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF263238),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Subtitle
                      Text(
                        _otpSent 
                            ? 'Enter the 6-digit code sent to your phone'
                            : 'We need to verify your phone number to enable chat features',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
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
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '3XXXXXXXXX',
                            prefixText: '+92 ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.length != 10) {
                              return 'Please enter a valid 10-digit phone number';
                            }
                            if (!value.startsWith('3')) {
                              return 'Please enter a valid Pakistan mobile number';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Send OTP Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _sendOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF263238),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Send OTP',
                                  style: TextStyle(fontSize: 16, color: Colors.white),
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
                          decoration: InputDecoration(
                            labelText: 'OTP Code',
                            hintText: 'Enter 6-digit code',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Verify OTP',
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Resend OTP
                        TextButton(
                          onPressed: _isLoading ? null : _sendOTP,
                          child: const Text(
                            'Resend OTP',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 48),
                      
                      // Cancel Option
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
