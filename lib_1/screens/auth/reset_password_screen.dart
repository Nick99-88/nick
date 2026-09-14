import 'package:flutter/material.dart';
import 'package:password_strength/password_strength.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth/auth_service.dart';
import 'login_screen.dart';
import '../../l10n/strings.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final AuthService _authService = AuthService();

  double _strength = 0;
  bool _isLoading = false;
  bool _isObscure = true;

  void _checkPassword(String value) {
    setState(() => _strength = estimatePasswordStrength(value));
  }

  void _handleReset() async {
    // 1. 🏛️ Institutional Validation
    if (_passController.text.length < 8) {
      StarlightUtils.showErrorBox(context, tr('passwordMin8'));
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      StarlightUtils.showErrorBox(context, tr('passwordsDoNotMatchExcl'));
      return;
    }

    if (_strength < 0.5) {
      StarlightUtils.showErrorBox(context, tr('passwordStrengthLow'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.resetPassword(
        email: widget.email,
        newPassword: _passController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, result['message']);

        // 🏛️ Move to Login Screen and clear stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
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
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.vpn_key_rounded, size: 80, color: StarlightTheme.primaryBlue),
            const SizedBox(height: 24),
            Text(tr('newVaultKey'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text(tr('setHighSecurityPassword'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),

            // 🏛️ New Password
            TextField(
              controller: _passController,
              obscureText: _isObscure,
              onChanged: _checkPassword,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
                labelText: tr('newPassword'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildStrengthBar(),
            const SizedBox(height: 16),

            // 🏛️ Confirm
            TextField(
              controller: _confirmPassController,
              obscureText: true,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
                labelText: tr('confirmNewPassword'),
                prefixIcon: Icon(Icons.shield_outlined),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _handleReset,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(tr('updatePasswordButton')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthBar() {
    Color strengthColor = _strength < 0.4 ? Colors.red : _strength < 0.7 ? Colors.orange : Colors.green;
    return LinearProgressIndicator(
      value: _strength,
      backgroundColor: Colors.grey[200],
      color: strengthColor,
      minHeight: 4,
    );
  }
}