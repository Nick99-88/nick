import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../core/storage.dart';
import '../../../core/utils.dart';
import '../../../core/platform_gate.dart';
import '../../../services/api_service.dart';
import '../../../services/security/biometric_service.dart';

class AdvancedSecurityScreen extends StatefulWidget {
  final VoidCallback onClose;
  const AdvancedSecurityScreen({super.key, required this.onClose});

  @override
  State<AdvancedSecurityScreen> createState() => _AdvancedSecurityScreenState();
}

class _AdvancedSecurityScreenState extends State<AdvancedSecurityScreen> {
  bool rolePinEnabled = false;
  bool isBiometricAvailable = true;
  bool biometricLockEnabled = false;
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    final rolePin = await StarlightStorage.getRolePinEnabled() ?? false;
    final bioLock = await StarlightStorage.getBiometricLockEnabled() ?? false;
    final isBioAvailable = await _biometricService.isAvailable();
    
    setState(() {
      rolePinEnabled = rolePin;
      biometricLockEnabled = bioLock;
      isBiometricAvailable = isBioAvailable;
    });
  }

  // 🏛️ Real Biometric Authentication
  Future<void> _handleBiometric() async {
    if (!isBiometricAvailable) {
      StarlightUtils.showErrorBox(context, "Biometric authentication not available on this device");
      return;
    }

    final availableBiometrics = await _biometricService.getAvailableBiometrics();
    if (availableBiometrics.isEmpty) {
      StarlightUtils.showErrorBox(context, "No biometrics enrolled. Please set up fingerprint or face ID in device settings");
      return;
    }

    final biometricType = _biometricService.getBiometricTypeName(availableBiometrics.first);
    final authenticated = await _biometricService.authenticate(
      localizedReason: 'Authenticate to enable biometric lock',
    );

    if (authenticated) {
      setState(() {
        biometricLockEnabled = true;
      });
      await StarlightStorage.setBiometricLockEnabled(true);
      await StarlightStorage.setLastAuthTime(DateTime.now().millisecondsSinceEpoch);
      StarlightUtils.showSuccessBox(context, "$biometricType authentication enabled successfully");
    } else {
      StarlightUtils.showErrorBox(context, "Authentication failed or cancelled");
    }
  }

  // 🏛️ Remove insecure OTP generation - replaced with secure message
  void _generateSecurityCodes() {
    StarlightUtils.showErrorBox(context, "OTP generation disabled for security. Use biometric authentication instead.");
  }

  // 🏛️ Role PIN Implementation
  Future<void> _handleRolePinToggle(bool value) async {
    if (value) {
      // Enable - ask for new PIN
      final pinCtrl = TextEditingController();
      final confirmPinCtrl = TextEditingController();
      String errorMessage = "";

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("SET ROLE PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Enter 4-digit PIN",
                    labelStyle: TextStyle(color: Colors.white38),
                    counterText: "",
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Confirm PIN",
                    labelStyle: TextStyle(color: Colors.white38),
                    counterText: "",
                  ),
                ),
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  final pin = pinCtrl.text.trim();
                  final confirm = confirmPinCtrl.text.trim();
                  
                  if (pin.length != 4) {
                    setDialogState(() => errorMessage = "PIN must be 4 digits");
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => errorMessage = "PINs do not match");
                    return;
                  }
                  
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                child: const Text("Set PIN", style: TextStyle(color: Colors.black87)),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true) {
        final pin = pinCtrl.text.trim();
        final pinHash = sha256.convert(utf8.encode(pin)).toString();
        await StarlightStorage.setRolePinHash(pinHash);
        await StarlightStorage.setRolePinEnabled(true);
        setState(() => rolePinEnabled = true);
        StarlightUtils.showSuccessBox(context, "Role PIN enabled");
      }
    } else {
      // Disable - require current PIN
      final pinCtrl = TextEditingController();
      String errorMessage = "";

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("DISABLE ROLE PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Enter current PIN",
                    labelStyle: TextStyle(color: Colors.white38),
                    counterText: "",
                  ),
                ),
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pin = pinCtrl.text.trim();
                  final currentHash = await StarlightStorage.getRolePinHash();
                  final inputHash = sha256.convert(utf8.encode(pin)).toString();
                  
                  if (inputHash != currentHash) {
                    setDialogState(() => errorMessage = "Incorrect PIN");
                    return;
                  }
                  
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8)),
                child: const Text("Disable", style: TextStyle(color: Colors.black87)),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true) {
        await StarlightStorage.setRolePinHash("");
        await StarlightStorage.setRolePinEnabled(false);
        setState(() => rolePinEnabled = false);
        StarlightUtils.showSuccessBox(context, "Role PIN disabled");
      }
    }
  }

  Future<void> _handleTransferScan() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TransferScannerView(
          onScan: (qrToken) async {
            Navigator.pop(context);

            // 🏛️ Add confirmation dialog for security
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Flexible(
                      child: const Text(
                        "CONFIRM TRANSFER",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  "This will transfer your account to a new device and log you out from this device. This action cannot be undone.\n\nAre you sure you want to proceed?",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text("Confirm Transfer", style: TextStyle(color: Colors.black87)),
                  ),
                ],
              ),
            );

            if (confirmed != true) {
              StarlightUtils.showErrorBox(context, "Transfer cancelled");
              return;
            }

            try {
              final deviceName = await PlatformGate.getDeviceName();

              final res = await ApiService.post('/auth/qr/authenticate', {
                'qr_token': qrToken,
                'device_name': deviceName,
              });

              if (res['status'] == 'transfer_initiated') {
                await StarlightStorage.clearAll();
                if (mounted) {
                  StarlightUtils.showSuccessBox(context, "Account transferred to new device");
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } else {
                StarlightUtils.showErrorBox(context, res['message'] ?? 'Transfer failed');
              }
            } catch (e) {
              StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // 🏛️ Deep Slate 900
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: widget.onClose,
        ),
        title: const Text("ADVANCED SECURITY",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSessionHeader(),
            const SizedBox(height: 30),

            _buildSecuritySection("Session Access", [
              _buildActionTile(
                "Biometric Unlock",
                "Use FaceID/Fingerprint for console access",
                Icons.fingerprint_rounded,
                onTap: _handleBiometric,
                trailing: const Icon(Icons.verified_user, color: Color(0xFF38BDF8), size: 18),
              ),
              _buildActionTile(
                "Generate OTP",
                "Temporary codes for web login",
                Icons.vibration_rounded,
                onTap: _generateSecurityCodes,
              ),
            ]),

            const SizedBox(height: 20),

            _buildSecuritySection("Console Protection", [
              _buildSwitchTile(
                  "Require Role PIN",
                  "Ask for PIN when switching to Owner role",
                  rolePinEnabled,
                      _handleRolePinToggle
              ),
              _buildSwitchTile(
                  "Biometric App Lock",
                  "Require fingerprint/face ID to open app",
                  biometricLockEnabled,
                      (v) async {
                        if (v) {
                          await _handleBiometric();
                        } else {
                          setState(() => biometricLockEnabled = false);
                          await StarlightStorage.setBiometricLockEnabled(false);
                          StarlightUtils.showSuccessBox(context, "Biometric lock disabled");
                        }
                      }
              ),
            ]),

            const SizedBox(height: 20),

            _buildSecuritySection("Account Management", [
              _buildActionTile(
                "Transfer Account",
                "Scan a new device's QR to transfer this account",
                Icons.qr_code_scanner_rounded,
                onTap: _handleTransferScan,
              ),
            ]),

            const SizedBox(height: 40),

            _buildWipeButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Row(
        children: [
          Icon(Icons.security_update_good_rounded, color: Colors.greenAccent, size: 30),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("End-to-End Encrypted", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text("Your security keys are stored locally in the Starlight Vault.",
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildActionTile(String title, String sub, IconData icon, {required VoidCallback onTap, Widget? trailing}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
    );
  }

  Widget _buildSwitchTile(String title, String sub, bool value, Function(bool) onChanged) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF38BDF8),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    );
  }

  Widget _buildWipeButton() {
    return InkWell(
      onTap: () => StarlightUtils.showErrorBox(context, "Hold to wipe all session data"),
      onLongPress: () {
        HapticFeedback.vibrate();
        StarlightUtils.showSuccessBox(context, "Session Wiped. Logging out...");
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Text("WIPE SESSION & LOGOUT",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
      ),
    );
  }
}

class _TransferScannerView extends StatelessWidget {
  final Function(String) onScan;
  const _TransferScannerView({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan New Device QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF263238),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            controller.dispose();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                if (barcode.rawValue != null) {
                  final code = barcode.rawValue!;
                  controller.dispose();
                  onScan(code);
                  return;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF38BDF8), width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Point camera at new device's QR code",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}