import 'package:flutter/material.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../services/security/biometric_service.dart';

/// Biometric lock screen that appears on app launch if biometric lock is enabled
/// Fails closed: there is NO way to bypass the lock. If biometrics are
/// unavailable the user can only log out. After 6 failed attempts the app
/// forces a logout and returns to the login screen.
class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  static const int maxFailedAttempts = 6;
  const BiometricLockScreen({super.key, required this.onUnlock});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isAuthenticating = false;
  bool _isAvailable = false;
  String _biometricType = 'Biometric';
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadFailedAttempts();
    _checkAvailabilityAndAuthenticate();
  }

  Future<void> _loadFailedAttempts() async {
    var attempts = await StarlightStorage.getBiometricFailedAttempts();
    if (attempts >= BiometricLockScreen.maxFailedAttempts) {
      // A previous session hit the lockout but the app was killed before the
      // logout completed. Reset so the lock can be used again.
      attempts = 0;
      await StarlightStorage.setBiometricFailedAttempts(0);
    }
    if (mounted) {
      setState(() => _failedAttempts = attempts);
    }
  }

  Future<void> _checkAvailabilityAndAuthenticate() async {
    final available = await _biometricService.isAvailable();
    if (!available) {
      // Fail closed: never silently unlock when biometrics are unavailable.
      if (mounted) {
        setState(() => _isAvailable = false);
        StarlightUtils.showErrorBox(
          context,
          "Biometric authentication is not available. The lock cannot be bypassed. Log out to secure your session.",
        );
      }
      return;
    }

    final biometrics = await _biometricService.getAvailableBiometrics();
    if (biometrics.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isAvailable = true;
          _biometricType = _biometricService.getBiometricTypeName(biometrics.first);
        });
      }
      await _authenticate();
    } else if (mounted) {
      setState(() => _isAvailable = false);
      StarlightUtils.showErrorBox(
        context,
        "No biometrics are enrolled on this device. Enroll in device settings or log out.",
      );
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || !mounted) return;
    setState(() => _isAuthenticating = true);

    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Authenticate to access Starlight Console',
      biometricOnly: true,
    );

    if (!mounted) return;
    setState(() => _isAuthenticating = false);

    if (authenticated) {
      _failedAttempts = 0;
      await StarlightStorage.setBiometricFailedAttempts(0);
      await StarlightStorage.setLastAuthTime(DateTime.now().millisecondsSinceEpoch);
      widget.onUnlock();
      return;
    }

    // Fail closed: every failed or cancelled attempt counts toward lockout.
    _failedAttempts += 1;
    await StarlightStorage.setBiometricFailedAttempts(_failedAttempts);
    if (!mounted) return;

    if (_failedAttempts >= BiometricLockScreen.maxFailedAttempts) {
      StarlightUtils.showErrorBox(
        context,
        "Too many failed attempts. Logging out for security.",
      );
      await _forceLogout();
    } else {
      StarlightUtils.showErrorBox(
        context,
        "Authentication failed (${_failedAttempts}/${BiometricLockScreen.maxFailedAttempts} attempts).",
      );
    }
  }

  Future<void> _handleLogout() async {
    if (_isAuthenticating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Log Out",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Logging out ends this session. The biometric lock stays enabled for the next login.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Log Out", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _forceLogout();
    }
  }

  Future<void> _forceLogout() async {
    await StarlightStorage.logout();
    await StarlightStorage.setBiometricFailedAttempts(0);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF38BDF8),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isAuthenticating ? Icons.fingerprint : Icons.lock_outline,
                  size: 60,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _isAuthenticating ? 'Authenticating...' : 'Starlight Console',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isAuthenticating
                    ? 'Please use $_biometricType to unlock'
                    : (_isAvailable ? 'Tap to authenticate' : 'Biometric unavailable'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 48),
              if (!_isAuthenticating)
                ElevatedButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.fingerprint, size: 20),
                  label: Text(_isAvailable ? "Use $_biometricType" : "Unlock"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _handleLogout,
                child: Text(
                  "Log out",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
