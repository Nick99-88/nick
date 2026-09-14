import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'lock_preference.dart';
import 'lock_preferences.dart';

class LockScreen extends StatefulWidget {
  final String chatName;
  final VoidCallback onUnlocked;
  final VoidCallback? onCancel;

  const LockScreen({
    super.key,
    required this.chatName,
    required this.onUnlocked,
    this.onCancel,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  bool _isVerifying = false;
  String _error = '';
  LockPreference _pref = const LockPreference();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAndAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAndAuthenticate();
    }
  }

  Future<void> _loadAndAuthenticate() async {
    _pref = await LockPreferences.getLockPreference();
    if (!_pref.isEnabled) {
      widget.onUnlocked();
      return;
    }
    await _authenticateBiometrics();
  }

  Future<void> _authenticateBiometrics() async {
    setState(() {
      _isVerifying = true;
      _error = '';
    });
    try {
      final localAuth = LocalAuthentication();
      final authenticated = await localAuth.authenticate(
        localizedReason: 'Unlock ${widget.chatName} chat',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
      if (authenticated && mounted) {
        widget.onUnlocked();
      } else if (mounted) {
        setState(() => _error = 'Biometric verification failed. Try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Biometrics not available.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF075E54),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.onCancel != null)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: widget.onCancel,
                ),
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.fingerprint, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Chat Locked',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.chatName,
                        style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 32),
                      if (!_isVerifying)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _authenticateBiometrics,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Unlock with Biometrics'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF075E54),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      if (_isVerifying) const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      if (_error.isNotEmpty) Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(_error, style: const TextStyle(color: Colors.orange, fontSize: 14), textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
