import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'lock_preference.dart';
import 'lock_preferences.dart';

class LockSettingsScreen extends StatefulWidget {
  const LockSettingsScreen({super.key});

  @override
  State<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends State<LockSettingsScreen> {
  LockPreference _pref = const LockPreference();
  bool _isLoading = true;
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _pref = await LockPreferences.getLockPreference();
    final localAuth = LocalAuthentication();
    _biometricsAvailable = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      if (!_biometricsAvailable) {
        _showSnackBar('No biometrics available on this device');
        return;
      }
      final authenticated = await _authenticateWithBiometrics();
      if (!authenticated) {
        _showSnackBar('Biometric verification failed');
        return;
      }
      _pref = _pref.copyWith(isEnabled: true, lockType: LockType.biometrics);
      await LockPreferences.saveLockPreference(_pref);
      _showSnackBar('Chat lock enabled');
    } else {
      _pref = _pref.copyWith(isEnabled: false, lockType: LockType.none);
      await LockPreferences.saveLockPreference(_pref);
      setState(() {});
      _showSnackBar('Chat lock disabled');
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    final localAuth = LocalAuthentication();
    try {
      return await localAuth.authenticate(
        localizedReason: 'Authenticate to manage chat lock settings',
        biometricOnly: true,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      return false;
    }
  }

  void _clearPreferences() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Lock Settings?'),
        content: const Text('This will disable all chat locks.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await LockPreferences.reset();
    await _load();
    _showSnackBar('Lock settings reset');
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat Lock')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
        title: const Text('Chat Lock', style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Lock Chats', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_pref.isEnabled ? 'Chats are locked with biometrics' : 'Require face or fingerprint to open locked chats'),
                        value: _pref.isEnabled,
                        activeColor: const Color(0xFF075E54),
                        onChanged: _toggleEnabled,
                      ),
                    ],
                  ),
                ),
                if (_pref.isEnabled) ...[
                  const SizedBox(height: 20),
                  Text('Lock Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  _lockOptionTile(
                    icon: Icons.fingerprint,
                    title: 'Biometrics (Face / Fingerprint)',
                    subtitle: _biometricsAvailable ? 'Use face or fingerprint to unlock' : 'Not available on this device',
                    selected: true,
                    enabled: _biometricsAvailable,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: _clearPreferences,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                      label: const Text('Reset Lock Settings', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
                if (!_pref.isEnabled && !_biometricsAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(
                      'No biometrics available on this device. Lock chat feature is unavailable.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Text(
                _pref.isEnabled
                    ? 'Lock is active. Locked chats require biometric verification to open.'
                    : 'Enable lock to protect your private chats with face or fingerprint.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required bool enabled,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: const Color(0xFF075E54), width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, color: enabled ? const Color(0xFF263238) : Colors.grey, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: enabled ? const Color(0xFF263238) : Colors.grey)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          if (selected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF075E54).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Active', style: TextStyle(fontSize: 11, color: Color(0xFF075E54), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
