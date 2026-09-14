import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/platform_gate.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../core/router_gateway.dart';
import '../../core/identity_controller.dart';
import '../../services/api_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/secondary_verification_flow.dart';

/// Displays a 30-second lived QR code for device-to-device login.
/// The new device shows this QR; an already-authenticated device scans it
/// and calls /auth/qr/authenticate to authorize this device.
class QRLoginDisplayScreen extends StatefulWidget {
  const QRLoginDisplayScreen({super.key});

  @override
  State<QRLoginDisplayScreen> createState() => _QRLoginDisplayScreenState();
}

class _QRLoginDisplayScreenState extends State<QRLoginDisplayScreen> {
  String? _qrToken;
  String? _tempJwt;
  int _secondsLeft = 30;
  Timer? _countdownTimer;
  bool _isLoading = true;
  bool _isExpired = false;
  bool _isTransferred = false;
  bool _isUsed = false; // 🏛️ Single-use flag
  WebSocketChannel? _wsChannel;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _closeWebSocket();
    super.dispose();
  }

  void _closeWebSocket() {
    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    _wsChannel = null;
  }

  Future<void> _generateToken() async {
    _countdownTimer?.cancel();
    _closeWebSocket();
    setState(() {
      _isLoading = true;
      _isExpired = false;
      _isUsed = false; // 🏛️ Reset single-use flag
      _secondsLeft = 30;
    });

    try {
      final deviceId = await PlatformGate.getDeviceId();
      final data = await ApiService.post('/auth/qr/generate', {
        'hardware_id': deviceId,
      }, requireAuth: false);
      final token = data['qr_token'] as String?;
      final tempJwt = data['temp_jwt'] as String?;

      if (token == null) {
        throw Exception('No QR token returned');
      }

      if (mounted) {
        setState(() {
          _qrToken = token;
          _tempJwt = tempJwt;
          _isLoading = false;
        });
        _startCountdown();
        if (tempJwt != null) {
          _connectWebSocket(tempJwt);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.toString().contains('429')
            ? 'Please wait before generating a new QR code'
            : 'Failed to generate QR code';
        StarlightUtils.showErrorBox(context, msg);
      }
    }
  }

  void _connectWebSocket(String tempJwt) {
    _closeWebSocket();
    // 🏛️ Move JWT from URL to headers for security
    final wsUrl = '${StarlightConstants.wsBaseUrl}/ws/qr-login';

    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['starlight-qr'],
      );
      
      // 🏛️ Send JWT as first message in headers
      _wsChannel!.sink.add(jsonEncode({
        'type': 'auth',
        'token': tempJwt,
      }));
      
      _wsChannel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['event'] == 'login_data') {
            final handshakeData = data['data'] as Map<String, dynamic>?;
            if (handshakeData != null) {
              _handleLoginData(handshakeData);
            }
          }
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  Future<void> _handleLoginData(Map<String, dynamic> loginData) async {
    _countdownTimer?.cancel();
    _closeWebSocket();
    if (!mounted) return;

    // 🏛️ Mark token as used to prevent reuse
    if (_isUsed) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, "This QR code has already been used");
      }
      return;
    }
    setState(() => _isUsed = true);

    // 🏛️ MFA enabled & device not yet trusted — run secondary verification first
    if (loginData['secondary_verification_required'] == true) {
      final String phoneHint = loginData['phone_hint'] ?? "";
      final String userId = loginData['user_id'] ?? "";

      await launchSecondaryVerificationChallenge(
        context,
        phoneHint: phoneHint,
        userId: userId,
        onCompleted: (handshake) async {
          if (!mounted) return;
          await _completeLogin(handshake);
        },
        onCancel: () {
          if (mounted) {
            setState(() => _isUsed = false);
          }
        },
      );
      return;
    }

    await _completeLogin(loginData);
  }

  Future<void> _completeLogin(Map<String, dynamic> loginData) async {
    try {
      final String token = loginData['access_token'] ?? '';
      final String role = loginData['role'] ?? 'user';
      final bool hasIdentity = loginData['identity'] ?? false;
      final bool isProfileComplete = loginData['data_identifier'] ?? false;
      final String roleId = loginData['role_id']?.toString() ?? "0";
      final String? instToken = loginData['institution_id']?.toString();
      final String otkSeed = loginData['otk'] ?? "";
      final Map<String, dynamic> userData = loginData['user_data'] ?? {};

      // 🏛️ Verify device binding matches
      final currentDeviceId = await PlatformGate.getDeviceId();
      final qrDeviceId = loginData['device_id'] as String?;
      if (qrDeviceId != null && qrDeviceId != currentDeviceId) {
        throw Exception("Device mismatch. This QR code was generated for a different device.");
      }

      final authService = AuthService();
      await authService.finalizeLink(token: token, deviceId: currentDeviceId, seed: otkSeed);

      await StarlightStorage.saveUserSession(token, roleId);
      await StarlightStorage.setUserRole(role);
      await StarlightStorage.setIdentity(hasIdentity);
      if (isProfileComplete) {
        await StarlightStorage.setIdentityVerifyToken("IDENTITY_LOCKED");
      } else {
        await StarlightStorage.setIdentityVerifyToken("");
      }
      if (instToken != null && instToken.isNotEmpty) {
        await StarlightStorage.setInstitutionalToken(instToken);
        if (role == 'owner') {
          await StarlightStorage.setOwnerVerifyToken("OWNERSHIP_VERIFIED");
        }
      }

      if (userData.isNotEmpty) {
        await IdentityController.setFullIdentity(userData);
      }

      setState(() => _isTransferred = true);

      if (mounted) {
        StarlightUtils.showSuccessBox(context, "Logged in successfully via QR");
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(context, "Login failed. Please try again.");
      }
    }
  }

  void _startCountdown() {
    _secondsLeft = 30;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();
        _closeWebSocket();
        setState(() {
          _isExpired = true;
          _qrToken = null;
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR Login',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: StarlightTheme.primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _isTransferred
            ? _buildTransferredState()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2, size: 48, color: StarlightTheme.primaryBlue),
                    const SizedBox(height: 16),
                    const Text(
                      'Show this QR code to an\nalready logged-in device',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),

                    if (_isLoading)
                      const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_isExpired || _qrToken == null)
                      _buildExpiredState()
                    else
                      _buildQrCode(),

                    const SizedBox(height: 24),

                    if (!_isLoading && !_isExpired) _buildTimer(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQrCode() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: QrImageView(
        data: _qrToken!,
        size: 200,
        version: QrVersions.auto,
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildExpiredState() {
    return Container(
      height: 220,
      width: 220,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'QR Code Expired',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _generateToken,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Generate New QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final progress = _secondsLeft / 30;
    final color = _secondsLeft <= 10 ? Colors.red : StarlightTheme.primaryBlue;

    return Column(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Text(
                '$_secondsLeft',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Expires in $_secondsLeft seconds',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTransferredState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 60),
        const SizedBox(height: 16),
        const Text(
          "Transfer Complete",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Redirecting to home...",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: StarlightTheme.primaryBlue, strokeWidth: 2),
      ],
    );
  }
}
