import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/token_manager.dart';
import '../../core/utils.dart';
import '../../core/platform_gate.dart';
import '../../services/api_service.dart';

/// Displays a 30-second lived QR code for account transfer.
/// Device A (logged-in) shows this QR; Device B scans it to take over the account.
/// Listens on a WebSocket for the "transfer_completed" event, then finalizes logout.
class QRTransferDisplayScreen extends StatefulWidget {
  const QRTransferDisplayScreen({super.key});

  @override
  State<QRTransferDisplayScreen> createState() => _QRTransferDisplayScreenState();
}

class _QRTransferDisplayScreenState extends State<QRTransferDisplayScreen> {
  String? _qrToken;
  int _secondsLeft = 30;
  Timer? _countdownTimer;
  bool _isLoading = true;
  bool _isExpired = false;
  bool _isTransferred = false;
  WebSocketChannel? _wsChannel;

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _notifyServerCleanup();
    _closeWebSocket();
    super.dispose();
  }

  void _notifyServerCleanup() {
    if (_qrToken == null) return;
    try {
      final wsUrl = '${StarlightConstants.wsBaseUrl}/ws/transfer/$_qrToken?action=cancel';
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      channel.sink.close();
    } catch (_) {}
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
      _secondsLeft = 30;
    });

    try {
      final data = await ApiService.post('/auth/qr/generate-transfer', {}, requireAuth: true);
      final token = data['qr_token'] as String?;

      if (token == null) throw Exception('No QR token returned');

      if (mounted) {
        setState(() {
          _qrToken = token;
          _isLoading = false;
        });
        _startCountdown();
        _connectWebSocket();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.toString().contains('429')
            ? 'Please wait before generating a new transfer code'
            : 'Failed to generate transfer code: $e';
        StarlightUtils.showErrorBox(context, msg);
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
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _isExpired = true;
          _qrToken = null;
          timer.cancel();
          _closeWebSocket();
        }
      });
    });
  }

  Future<void> _connectWebSocket() async {
    _closeWebSocket();
    if (_qrToken == null) return;

    final jwt = await TokenManager.instance.getValidToken();
    if (jwt == null || jwt.isEmpty) return;

    // 🏛️ Move JWT from URL to headers for security
    final wsUrl = '${StarlightConstants.wsBaseUrl}/ws/transfer';

    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['starlight-transfer'],
      );
      
      // 🏛️ Send JWT and token as first message
      _wsChannel!.sink.add(jsonEncode({
        'type': 'auth',
        'token': jwt,
        'qr_token': _qrToken,
      }));
      
      _wsChannel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          if (data['event'] == 'transfer_completed') {
            _finalizeTransfer();
          }
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  Future<void> _finalizeTransfer() async {
    _countdownTimer?.cancel();
    _closeWebSocket();
    if (!mounted) return;

    setState(() => _isTransferred = true);

    // Clear all local credentials and redirect to login
    await StarlightStorage.clearAll();

    if (mounted) {
      StarlightUtils.showSuccessBox(context, "Account transferred to a new device");
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "TRANSFER ACCOUNT",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
        ),
      ),
      body: Center(
        child: _isTransferred
            ? _buildTransferredState()
            : _isLoading
                ? _buildLoadingState()
                : _isExpired
                    ? _buildExpiredState()
                    : _buildQrState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Color(0xFF38BDF8)),
        SizedBox(height: 16),
        Text("Generating transfer code...", style: TextStyle(color: Colors.white54)),
      ],
    );
  }

  Widget _buildQrState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.swap_horiz_rounded, color: Color(0xFF38BDF8), size: 40),
        const SizedBox(height: 12),
        const Text(
          "Scan on New Device",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          "This transfers your account to another device",
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: QrImageView(
            data: _qrToken!,
            size: 200,
            version: QrVersions.auto,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _secondsLeft / 30,
                strokeWidth: 4,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _secondsLeft > 10 ? const Color(0xFF38BDF8) : Colors.redAccent,
                ),
              ),
              Center(
                child: Text(
                  "$_secondsLeft",
                  style: TextStyle(
                    color: _secondsLeft > 10 ? Colors.white : Colors.redAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Waiting for scan...",
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildExpiredState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_off_rounded, color: Colors.redAccent, size: 50),
        const SizedBox(height: 16),
        const Text(
          "QR Code Expired",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "The transfer code has expired. Generate a new one.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _generateToken,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text("Generate New QR"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Redirecting to login...",
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 2),
      ],
    );
  }
}
