import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../core/router_gateway.dart';
import '../../services/nearby_permissions.dart';

class ChildConnectionScreen extends StatefulWidget {
  const ChildConnectionScreen({super.key});

  @override
  State<ChildConnectionScreen> createState() => _ChildConnectionScreenState();
}

class _ChildConnectionScreenState extends State<ChildConnectionScreen> {
  final Nearby _nearby = Nearby();
  bool _isDiscovering = false;
  bool _isConnected = false;
  bool _isLinking = false;
  String? _childName;
  String? _connectedEndpointId;
  String? _receivedToken;
  String _status = 'Ready to discover child devices';
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingLink();
  }

  @override
  void dispose() {
    _stopDiscovery();
    super.dispose();
  }

  Future<void> _checkExistingLink() async {
    final existingToken = await StarlightStorage.getParentLinkToken();
    if (existingToken != null && mounted) {
      setState(() {
        _status = 'Already linked to a child';
        _receivedToken = existingToken;
      });
    }
  }

  Future<void> _startDiscovery() async {
    debugPrint('🏛️ [ChildConnection] ===== _startDiscovery called =====');
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      debugPrint('🏛️ [ChildConnection] Skipped — not Android');
      setState(() => _status = 'Nearby is only available on Android');
      return;
    }

    try {
      debugPrint('🏛️ [ChildConnection] Checking permissions BEFORE discovery...');
      await requestNearbyPermissions();

      // Check which permissions are permanently denied (need app settings)
      final requiredPermissions = [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
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
        debugPrint('🏛️ [ChildConnection] Permanently denied: $permanentlyDenied');
        setState(() {
          _status = 'Permissions permanently denied: ${permanentlyDenied.join(", ")}';
          _error = 'Please enable these permissions in app settings.';
        });
        await openAppSettings();
        return;
      }

      // Second pass: request any remaining denied permissions
      if (denied.isNotEmpty) {
        debugPrint('🏛️ [ChildConnection] Requesting denied permissions: ${denied.map((p) => p.toString().split('.').last).toList()}');
        final newStatuses = await denied.request();
        for (final entry in newStatuses.entries) {
          if (!entry.value.isGranted) {
            final name = entry.key.toString().split('.').last;
            debugPrint('🏛️ [ChildConnection] Still denied after request: $name');
            setState(() {
              _status = 'Permission denied: $name';
              _error = 'Please enable "$name" in app settings.';
            });
            await openAppSettings();
            return;
          }
        }
      }

      debugPrint('🏛️ [ChildConnection] All permissions granted, starting discovery...');
      setState(() {
        _isDiscovering = true;
        _error = null;
        _status = 'Scanning for nearby student devices...';
      });

      await _nearby.startDiscovery(
        'Parent',
        Strategy.P2P_STAR,
        onEndpointFound: (endpointId, name, serviceId) {
          _onEndpointFound(endpointId, name);
        },
        onEndpointLost: (endpointId) {},
        serviceId: 'STARLIGHT_FAMILY',
      );
    } catch (e) {
      setState(() {
        _isDiscovering = false;
        _status = 'Scan error: ${e.toString()}';
        _error = e.toString();
      });
    }
  }

  Future<void> _stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
    } catch (_) {}
    if (mounted) {
      setState(() => _isDiscovering = false);
    }
  }

  void _onEndpointFound(String endpointId, String name) {
    _stopDiscovery();

    _nearby.requestConnection(
      'Parent',
      endpointId,
      onConnectionInitiated: (endpointId, connectionInfo) {
        _nearby.acceptConnection(
          endpointId,
          onPayLoadRecieved: (endpointId, payload) {
            _onPayloadReceived(endpointId, payload);
          },
          onPayloadTransferUpdate: (endpointId, payloadTransferUpdate) {},
        );

        if (mounted) {
          setState(() {
            _childName = connectionInfo.endpointName;
            _status = 'Connecting to ${connectionInfo.endpointName}...';
          });
        }
      },
      onConnectionResult: (endpointId, status) {
        if (status == Status.CONNECTED) {
          setState(() {
            _isConnected = true;
            _connectedEndpointId = endpointId;
            _status = 'Connected to $_childName! Waiting for token...';
          });
        } else {
          setState(() {
            _status = 'Connection failed: $status';
          });
        }
      },
      onDisconnected: (endpointId) {
        setState(() {
          _isConnected = false;
          _connectedEndpointId = null;
          if (_receivedToken == null) {
            _status = 'Child disconnected before sending token';
          }
        });
      },
    );
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      final token = String.fromCharCodes(payload.bytes!);
      if (token.length == 18 && RegExp(r'^\d{18}$').hasMatch(token)) {
        setState(() {
          _receivedToken = token;
          _status = 'Token received! Linking to server...';
        });

        _linkToServer(token);

        // Send ACK back to child
        _nearby.sendBytesPayload(
          endpointId,
          Uint8List.fromList('TOKEN_ACK'.codeUnits),
        );
      }
    }
  }

  Future<void> _linkToServer(String token) async {
    setState(() => _isLinking = true);

    try {
      final userToken = await StarlightStorage.getUserToken();
      if (userToken == null) throw Exception("Session expired. Please login again.");

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/parent/link-child'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $userToken',
        },
        body: jsonEncode({'token': token}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        // Store the parent link token
        await StarlightStorage.setParentLinkToken(token);

        if (mounted) {
          setState(() {
            _status = 'Successfully linked to child!';
            _isLinking = false;
          });

          // Show success and navigate
          _showSuccessDialog();
        }
      } else {
        throw Exception(data['detail'] ?? 'Failed to link child');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Link failed: ${e.toString()}';
          _isLinking = false;
          _error = e.toString();
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            Text('Success!', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'You are now linked to your child. You can monitor their academic progress from your dashboard.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              UniversalRouter.routeUser(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue),
            child: Text('GO TO DASHBOARD', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Children Connection',
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
                color: _receivedToken != null
                    ? Colors.green.withOpacity(0.1)
                    : StarlightTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    _receivedToken != null
                        ? Icons.check_circle_outline
                        : Icons.bluetooth_searching,
                    size: 70,
                    color: _receivedToken != null
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
                  if (_isDiscovering) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(strokeWidth: 2),
                  ],
                  if (_isLinking) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(strokeWidth: 2),
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
                    _buildStep(1, 'Ask your child to open "My Parent" in their profile'),
                    _buildStep(2, 'Tap "Start Connecting" on their device'),
                    _buildStep(3, 'Tap "Start Scanning" below on your device'),
                    _buildStep(4, 'A secure 18-digit token will be sent automatically'),
                    _buildStep(5, 'The token links your accounts on the server'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Scan Button
            if (_receivedToken == null) ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isDiscovering ? _stopDiscovery : _startDiscovery,
                  icon: Icon(
                    _isDiscovering ? Icons.stop : Icons.bluetooth_searching,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isDiscovering ? 'STOP SCANNING' : 'START SCANNING',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDiscovering ? Colors.red : StarlightTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Token received info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.vpn_key, color: Colors.green[700], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Token Received & Verified',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.green[800],
                            ),
                          ),
                          Text(
                            'Your child is now linked to your account',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    UniversalRouter.routeUser(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'GO TO DASHBOARD',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
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
