import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/storage.dart';
import '../../services/auth/firebase_phone_service.dart';

class ChangePhoneScreen extends StatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPhoneController = TextEditingController();
  final _newPhoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = true;
  bool _otpSent = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPhone();
  }

  @override
  void dispose() {
    _oldPhoneController.dispose();
    _newPhoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPhone() async {
    final phone = await StarlightStorage.getVerifiedPhone();
    if (phone != null) {
      _oldPhoneController.text = phone;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final success = await FirebasePhoneService.sendOTPToPakistan(_newPhoneController.text.trim());
      if (success) {
        if (mounted) setState(() => _otpSent = true);
        _showSuccess('OTP sent to new number');
      } else {
        _showError('Failed to send OTP');
      }
    } catch (e) {
      _showError('Failed to send OTP: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final success = await FirebasePhoneService.verifyOTP(_otpController.text.trim());
      if (success) {
        final newPhone = _newPhoneController.text.trim();
        final currentUser = FirebasePhoneService.currentUser;
        final phoneNumber = currentUser?.phoneNumber ?? '+92$newPhone';

        await StarlightStorage.setVerifiedPhone(phoneNumber);
        await StarlightStorage.setChatVerified(true);

        final firebaseUid = currentUser?.uid ?? '';
        await FirebasePhoneService.verifyWithServer(phoneNumber, FirebasePhoneService.apiToken, firebaseUid);

        _showSuccess('Phone number changed successfully!');
        if (mounted) Navigator.pop(context, true);
      } else {
        _showError('Invalid OTP');
      }
    } catch (e) {
      _showError('Verification failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
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
          'Change Phone Number',
          style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_android, size: 64, color: Colors.blue),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _otpSent ? 'Enter OTP' : 'Change Phone Number',
                      style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF263238),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _otpSent
                          ? 'Enter the 6-digit code sent to your new number'
                          : 'Enter your new phone number to receive OTP',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Old phone number (read-only)
                    TextFormField(
                      controller: _oldPhoneController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Current Phone Number',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!_otpSent) ...[
                      // New phone number
                      TextFormField(
                        controller: _newPhoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          labelText: 'New Phone Number',
                          hintText: '3XXXXXXXXX',
                          prefixText: '+92 ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      ElevatedButton(
                        onPressed: _isLoading ? null : _sendOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF263238),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Send OTP', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],

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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.length != 6) {
                            return 'Please enter a valid 6-digit OTP';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Verify OTP', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading ? null : _sendOTP,
                        child: const Text('Resend OTP', style: TextStyle(color: Colors.blue)),
                      ),
                    ],

                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
