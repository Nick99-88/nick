import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nearby_connections/nearby_connections.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../services/nearby_permissions.dart';

class ParentConnectionScreen extends StatefulWidget {
  const ParentConnectionScreen({super.key});

  @override
  State<ParentConnectionScreen> createState() => _ParentConnectionScreenState();
}

class _ParentConnectionScreenState extends State<ParentConnectionScreen> {
  final Nearby _nearby = Nearby();
  bool _isAdvertising = false;
  bool _isConnected = false;
  bool _tokenSent = false;
  String? _parentName;
  String? _connectedEndpointId;
  String _status = 'Ready to connect';
  String? _error;
  int _tokenExpirySeconds = 120;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _checkExistingConnection();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _stopAdvertising();
    super.dispose();
  }

  Future<void> _checkExistingConnection() async {
    final hasParentToken = await StarlightStorage.getParentLinkToken();
    if (hasParentToken != null && mounted) {
      setState(() {
        _status = 'Already connected to a parent';
        _tokenSent = true;
      });
    }
  }

  String _generateToken() {
    final random = Random.secure();
    final token = List<int>.generate(18, (_) => random.nextInt(10));
    return token.join();
  }

  Future<void> _startAdvertising() async {
    debugPrint('🏛️ [ParentConnection] ===== _startAdvertising called =====');
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('🏛️ [ParentConnection] Skipped — not Android');
      setState(() => _status = 'Nearby is only available on Android');
      return;
    }

    try {
      debugPrint('🏛️ [ParentConnection] Checking permissions BEFORE advertising...');
      await requestNearbyPermissions();

      // Check which permissions are permanently denied (need app settings)
      final requiredPermissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.nearbyWifiDevices,
        Permission.locationWhenInUse,
      ];

      // First pass: check current status
      final statuses = await Future.wait(requiredPermissions.map((p) => p.status));
      final permanentlyDenied = <String>[];
      final denied = <Permission>[];

      for (var i = 0; i < requiredPermissions.length; i++) {
        final name = requiredPermissions[i].toString().split('.').last;
        if (statuses[i].isPermanentlyDenied) {
          permanentlyDenied.add(name);
        } else if (!statuses[i].isGranted) {
          denied.add(requiredPermissions[i]);
        }
      }

      // If any permanently denied, must go to settings
      if (permanentlyDenied.isNotEmpty) {
        debugPrint('🏛️ [ParentConnection] Permanently denied: $permanentlyDenied');
        setState(() {
          _status = 'Permissions permanently denied: ${permanentlyDenied.join(", ")}';
          _error = 'Please enable these permissions in app settings.';
        });
        await openAppSettings();
        return;
      }

      // Second pass: request any remaining denied permissions
      if (denied.isNotEmpty) {
        debugPrint('🏛️ [ParentConnection] Requesting denied permissions: ${denied.map((p) => p.toString().split('.').last).toList()}');
        final newStatuses = await denied.request();
        for (final entry in newStatuses.entries) {
          if (!entry.value.isGranted) {
            final name = entry.key.toString().split('.').last;
            debugPrint('🏛️ [ParentConnection] Still denied after request: $name');
            setState(() {
              _status = 'Permission denied: $name';
              _error = 'Please enable "$name" in app settings.';
            });
            await openAppSettings();
            return;
          }
        }
      }

      debugPrint('🏛️ [ParentConnection] All permissions granted, starting advertising...');

      final userName = await StarlightStorage.getUserName() ?? 'Student';
      debugPrint('🏛️ [ParentConnection] Starting advertising as "$userName"...');
      setState(() {
        _isAdvertising = true;
        _status = 'Searching for parent device...';
      });

      await _nearby.startAdvertising(
        userName,
        Strategy.P2P_STAR,
        onConnectionInitiated: (endpointId, connectionInfo) {
          _onConnectionInitiated(endpointId, connectionInfo);
        },
        onConnectionResult: (endpointId, status) {
          _onConnectionResult(endpointId, status);
        },
        onDisconnected: (endpointId) {
          _onDisconnected(endpointId);
        },
        serviceId: 'STARLIGHT_FAMILY',
      );
    } catch (e) {
      setState(() {
        _isAdvertising = false;
        _status = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
    } catch (_) {}
    if (mounted) {
      setState(() => _isAdvertising = false);
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo connectionInfo) {
    _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        _onPayloadReceived(endpointId, payload);
      },
      onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
    );

    if (mounted) {
      setState(() {
        _parentName = connectionInfo.endpointName;
        _status = 'Connecting to ${connectionInfo.endpointName}...';
      });
    }
  }

  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      setState(() {
        _isConnected = true;
        _connectedEndpointId = endpointId;
        _status = 'Connected to $_parentName!';
      });

      _generateAndSendToken(endpointId);
    } else {
      setState(() {
        _isConnected = false;
        _status = 'Connection failed: $status';
      });
    }
  }

  void _onDisconnected(String endpointId) {
    setState(() {
      _isConnected = false;
      _connectedEndpointId = null;
      _status = 'Parent disconnected';
    });
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      final data = String.fromCharCodes(payload.bytes!);
      if (data == 'TOKEN_ACK') {
        setState(() {
          _status = 'Token received by parent. Connection complete!';
        });
      }
    }
  }

  Future<void> _generateAndSendToken(String endpointId) async {
    final token = _generateToken();

    setState(() {
      _status = 'Sending connection token to parent...';
    });

    await _nearby.sendBytesPayload(
      endpointId,
      Uint8List.fromList(token.codeUnits),
    );

    // Start expiry timer (2 minutes)
    _tokenExpirySeconds = 120;
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_tokenExpirySeconds > 0) {
        setState(() => _tokenExpirySeconds--);
      } else {
        timer.cancel();
        if (mounted && !_tokenSent) {
          setState(() => _status = 'Token expired. Please try again.');
        }
      }
    });

    setState(() {
      _tokenSent = true;
      _status = 'Token sent! Waiting for parent to verify...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Connect Parent',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green.withOpacity(0.1)
                    : StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    _tokenSent
                        ? Icons.check_circle_outline
                        : _isAdvertising
                            ? Icons.bluetooth_searching
                            : Icons.family_restroom,
                    size: 70,
                    color: _tokenSent
                        ? Colors.green
                        : StarlightTheme.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (_isAdvertising && !_isConnected) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(strokeWidth: 2),
                  ],
                  if (_tokenSent && _tokenExpirySeconds > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Token expires in $_tokenExpirySeconds seconds',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // How it works
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStep(1, 'Ask your parent to open the Children Connection screen'),
                    _buildStep(2, 'Tap "Start Scanning" on their device'),
                    _buildStep(3, 'Tap "Start Connecting" below on your device'),
                    _buildStep(4, 'A token will be sent to your parent automatically'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Connect Button
            if (!_tokenSent) ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isAdvertising ? _stopAdvertising : _startAdvertising,
                  icon: Icon(
                    _isAdvertising ? Icons.stop : Icons.bluetooth_searching,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isAdvertising ? 'STOP SCANNING' : 'START CONNECTING',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAdvertising ? Colors.red : StarlightTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Token display (for reference)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Connection Token (sent to parent)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A 18-digit token has been sent to your parent\'s device.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: StarlightTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'BACK TO PROFILE',
                    style: GoogleFonts.poppins(
                      color: StarlightTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
