import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starlight_flutter/chat_system/services/call_signaling_service.dart';
import 'package:starlight_flutter/chat_system/services/call_kit_service.dart';
import 'package:starlight_flutter/chat_system/services/proximity_wake_lock.dart';
import 'package:starlight_flutter/services/socket/enhanced_socket_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Isolated Call Screen - launched directly from CallActivity (Android)
/// This screen is used when the app is opened from a call notification
/// and provides a dedicated call interface with foreground service support.
class IsolatedCallScreen extends StatefulWidget {
  const IsolatedCallScreen({super.key});

  @override
  State<IsolatedCallScreen> createState() => _IsolatedCallScreenState();
}

class _IsolatedCallScreenState extends State<IsolatedCallScreen>
    with SingleTickerProviderStateMixin {
  static const _callChannel = MethodChannel('com.starlight.console/call_activity');
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<CallSession>? _callSubscription;
  CallSession? _session;
  Timer? _durationTimer;
  Timer? _ringTimer;
  Timer? _ringingTimeoutTimer;
  Timer? _maxCallTimer;

  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideo = false;
  bool _cameraOff = false;
  bool _initialized = false;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  List<RTCIceCandidate> _pendingCandidates = [];

  final Map<String, dynamic> _configMap = {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
    'optional': [],
  };

  String? _peerUserId;
  bool _socketChecked = false;

  StreamSubscription<dynamic>? _proximitySub;
  static const _proximityChannel = EventChannel('com.starlight.console/proximity');

  Map<String, dynamic>? _callData;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _localRenderer.initialize();
    _remoteRenderer.initialize();

    _loadCallDataAndInitialize();
  }

  Future<void> _loadCallDataAndInitialize() async {
    print('📞 IsolatedCall: _loadCallDataAndInitialize called');
    try {
      print('📞 IsolatedCall: Invoking getCallData method on native channel');
      final data = await _callChannel.invokeMethod('getCallData') as Map<String, dynamic>?;
      print('📞 IsolatedCall: Received call data: $data');
      
      if (data != null) {
        print('📞 IsolatedCall: Call data is valid, setting state');
        setState(() {
          _callData = data;
          _isVideo = data['call_type'] == 'video';
        });
        print('📞 IsolatedCall: Initializing call from data');
        await _initializeCallFromData(data);
      } else {
        print('📞 IsolatedCall: ERROR - Call data is null');
      }
    } catch (e) {
      print('📞 IsolatedCall: ERROR loading call data - $e');
      print('📞 IsolatedCall: Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _initializeCallFromData(Map<String, dynamic> data) async {
    print('📞 IsolatedCall: _initializeCallFromData called');
    
    final callId = data['call_id'] as String? ?? '';
    final callerName = data['caller_name'] as String? ?? 'Unknown';
    final callerPhone = data['caller_phone'] as String? ?? '';
    final callType = data['call_type'] as String? ?? 'voice';
    final callerAvatar = data['caller_avatar'] as String? ?? '';
    final peerUserId = data['peer_user_id'] as String? ?? '';
    final isIncoming = data['is_incoming'] as bool? ?? true;

    print('📞 IsolatedCall: Initializing call from notification - $callerName');
    print('📞 IsolatedCall: Call details - ID: $callId, Type: $callType, Incoming: $isIncoming');

    if (callId.isEmpty) {
      print('📞 IsolatedCall: ERROR - Call ID is empty, cannot initialize call');
      return;
    }

    try {
      // Check socket connection
      print('📞 IsolatedCall: Checking socket connection...');
      final socketAlive = await _checkSocketConnection();
      if (!socketAlive) {
        print('📞 IsolatedCall: Socket not alive, connecting...');
        await _ensureSocketConnected();
      }

      // Set up send channel for call signaling
      print('📞 IsolatedCall: Setting up send channel');
      _setupSendChannel();

      // Create or restore call session
      print('📞 IsolatedCall: Creating call session');
      final session = CallSession(
        callId: callId,
        peerUserId: peerUserId,
        peerPhone: callerPhone,
        peerName: callerName,
        peerAvatar: callerAvatar,
        type: callType == 'video' ? CallType.video : CallType.voice,
        state: CallState.ringing,
        direction: isIncoming ? CallDirection.incoming : CallDirection.outgoing,
      );

      print('📞 IsolatedCall: Setting active call in CallSignalingService');
      CallSignalingService.instance.setActiveCall(session);
      _session = session;
      _peerUserId = peerUserId;

      // Subscribe to call state changes
      print('📞 IsolatedCall: Subscribing to call state stream');
      _callSubscription = CallSignalingService.instance.callStateStream.listen(_onCallState);

      // Set up WebRTC signal handler
      print('📞 IsolatedCall: Setting up WebRTC signal handler');
      CallSignalingService.instance.onWebRtcSignal = _handleWebRtcSignal;

      print('📞 IsolatedCall: Starting call UI');
      // If incoming call, start ringing UI
      if (isIncoming) {
        _startIncomingCall();
      } else {
        _startOutgoingCall();
      }
      
      print('📞 IsolatedCall: Call initialization complete');
    } catch (e) {
      print('📞 IsolatedCall: ERROR during call initialization - $e');
      print('📞 IsolatedCall: Stack trace: ${StackTrace.current}');
    }
  }

  Future<bool> _checkSocketConnection() async {
    if (_socketChecked) return true;
    _socketChecked = true;

    print('📞 IsolatedCall: Checking socket connection with ping/pong...');
    final isAlive = await EnhancedSocketService.pingServer();
    print('📞 IsolatedCall: Socket alive: $isAlive');
    return isAlive;
  }

  Future<void> _ensureSocketConnected() async {
    if (EnhancedSocketService.isConnected()) {
      print('📞 IsolatedCall: Socket already connected');
      return;
    }

    try {
      print('📞 IsolatedCall: Connecting socket...');
      await EnhancedSocketService.connect(source: 'IsolatedCallScreen');
      print('📞 IsolatedCall: Socket connected successfully');
    } catch (e) {
      print('📞 IsolatedCall: Socket connection failed - $e');
    }
  }

  void _setupSendChannel() {
    CallSignalingService.instance.setSendViaChatChannel((json) async {
      print('📞 IsolatedCall: Sending signaling message');
      try {
        if (EnhancedSocketService.isConnected()) {
          EnhancedSocketService.sendRawMessage(json);
        } else {
          print('📞 IsolatedCall: Socket not connected, ensuring connection...');
          await _ensureSocketConnected();
          if (EnhancedSocketService.isConnected()) {
            EnhancedSocketService.sendRawMessage(json);
          } else {
            print('📞 IsolatedCall: Failed to connect socket for signaling');
          }
        }
      } catch (e) {
        print('📞 IsolatedCall: Error sending signaling - $e');
      }
    });
  }

  void _onCallState(CallSession session) async {
    if (!mounted) return;
    setState(() => _session = session);

    if (session.state == CallState.connected) {
      _onCallConnected(session);
    } else if (_isTerminalState(session.state)) {
      _stopRingingFeedback();
      _durationTimer?.cancel();
      _ringingTimeoutTimer?.cancel();
      _maxCallTimer?.cancel();
      _cleanupWebRtc();
      await _stopProximitySensorAndRestore();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _callChannel.invokeMethod('endCall');
        }
      });
    }
  }

  bool _isTerminalState(CallState state) {
    return state == CallState.ended ||
           state == CallState.rejected ||
           state == CallState.missed ||
           state == CallState.busy;
  }

  void _startIncomingCall() {
    print('📞 IsolatedCall: Starting incoming call UI');
    print('📞 IsolatedCall: Hiding CallKit incoming call to prevent duplicate UI');
    CallKitService.instance.hideIncomingCall(_session!.callId);
    _startRingingFeedback();
    _startRingingTimeout();
  }

  void _startOutgoingCall() {
    print('📞 IsolatedCall: Starting outgoing call UI');
    _startRingingFeedback();
    _startRingingTimeout();
    CallKitService.instance.showOutgoingCall(
      callId: _session!.callId,
      calleeName: _session!.peerName,
      calleeHandle: _session!.peerPhone,
      callType: _session!.type.name,
    );
  }

  void _onCallConnected(CallSession session) async {
    print('📞 IsolatedCall: Call connected, initializing WebRTC');
    _stopRingingFeedback();
    _ringingTimeoutTimer?.cancel();

    _startDurationTimer();
    _startMaxCallTimer();
    await _initProximitySensor();

    if (session.direction == CallDirection.outgoing) {
      await _initMediaAndCreateOffer();
    } else {
      await _initMediaAndAnswer();
    }
  }

  Future<void> _initMediaAndCreateOffer() async {
    print('📞 IsolatedCall: Creating offer');
    try {
      print('📞 IsolatedCall: Getting user media...');
      _localStream = await _getUserMedia();
      print('📞 IsolatedCall: Got local stream with ${_localStream!.getAudioTracks().length} audio tracks and ${_localStream!.getVideoTracks().length} video tracks');
      _localRenderer.srcObject = _localStream;
      print('📞 IsolatedCall: Set local renderer source');

      await _createPeerConnection();
      print('📞 IsolatedCall: Peer connection created');
      
      _localStream!.getTracks().forEach((track) {
        print('📞 IsolatedCall: Adding track to peer connection: ${track.kind}');
        _peerConnection!.addTrack(track, _localStream!);
      });

      print('📞 IsolatedCall: Creating offer with config: $_configMap');
      final description = await _peerConnection!.createOffer(_configMap);
      print('📞 IsolatedCall: Offer created, setting local description');
      await _peerConnection!.setLocalDescription(description);
      print('📞 IsolatedCall: Local description set, sending offer signal');
      _sendWebRtcSignal({'type': 'offer', 'sdp': description.sdp});
      print('📞 IsolatedCall: Offer signal sent');
    } catch (e) {
      print('📞 IsolatedCall: Error creating offer - $e');
    }
  }

  Future<void> _initMediaAndAnswer() async {
    print('📞 IsolatedCall: Creating answer');
    try {
      print('📞 IsolatedCall: Getting user media for answer...');
      _localStream = await _getUserMedia();
      print('📞 IsolatedCall: Got local stream with ${_localStream!.getAudioTracks().length} audio tracks and ${_localStream!.getVideoTracks().length} video tracks');
      _localRenderer.srcObject = _localStream;
      print('📞 IsolatedCall: Set local renderer source');

      await _createPeerConnection();
      print('📞 IsolatedCall: Peer connection created');
      
      _localStream!.getTracks().forEach((track) {
        print('📞 IsolatedCall: Adding track to peer connection: ${track.kind}');
        _peerConnection!.addTrack(track, _localStream!);
      });
      print('📞 IsolatedCall: Tracks added, waiting for offer to create answer');
    } catch (e) {
      print('📞 IsolatedCall: Error creating answer - $e');
    }
  }

  Future<MediaStream> _getUserMedia() async {
    final constraints = {
      'audio': true,
      'video': _isVideo ? {'facingMode': 'user'} : false,
    };
    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<void> _createPeerConnection() async {
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun3.l.google.com:19302'},
        {'urls': 'stun:stun4.l.google.com:19302'},
        {'urls': 'turn:openrelay.metered.ca:80', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
        {'urls': 'turn:openrelay.metered.ca:443', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
        {'urls': 'turn:openrelay.metered.ca:443?transport=tcp', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
      ],
      'sdpSemantics': 'unified-plan',
    };
    print('📞 IsolatedCall: Creating peer connection with TURN servers for NAT traversal');
    _peerConnection = await createPeerConnection(config);
    print('📞 IsolatedCall: Peer connection created');

    _peerConnection!.onIceCandidate = (candidate) {
      print('📞 IsolatedCall: ICE candidate generated');
      _sendWebRtcSignal({
        'type': 'candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('📞 IsolatedCall: ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        print('📞 IsolatedCall: ICE connection established - media should flow');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        print('📞 IsolatedCall: ICE connection failed - media will not flow');
      }
    };

    _peerConnection!.onTrack = (event) {
      print('📞 IsolatedCall: Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        print('📞 IsolatedCall: Setting remote renderer source');
        _remoteRenderer.srcObject = event.streams[0];
      } else {
        print('📞 IsolatedCall: WARNING - Remote track has no streams');
      }
    };
    
    _peerConnection!.onConnectionState = (state) {
      print('📞 IsolatedCall: Peer connection state: $state');
    };
  }

  void _handleWebRtcSignal(Map<String, dynamic> signal) {
    print('📞 IsolatedCall: Received WebRTC signal: ${signal['type']}');
    print('📞 IsolatedCall: Signal data: $signal');
    
    if (_peerConnection == null) {
      print('📞 IsolatedCall: ERROR - Peer connection is null, cannot handle signal');
      return;
    }

    switch (signal['type']) {
      case 'offer':
        print('📞 IsolatedCall: Handling offer');
        _handleOffer(signal['sdp']);
        break;
      case 'answer':
        print('📞 IsolatedCall: Handling answer');
        _handleAnswer(signal['sdp']);
        break;
      case 'candidate':
        print('📞 IsolatedCall: Handling ICE candidate');
        _handleCandidate(signal);
        break;
      default:
        print('📞 IsolatedCall: Unknown signal type: ${signal['type']}');
    }
  }

  void _handleOffer(String? sdp) async {
    print('📞 IsolatedCall: _handleOffer called');
    if (sdp == null) {
      print('📞 IsolatedCall: ERROR - SDP is null');
      return;
    }
    print('📞 IsolatedCall: Setting remote description (offer)');
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    print('📞 IsolatedCall: Creating answer with config: $_configMap');
    final answer = await _peerConnection!.createAnswer(_configMap);
    print('📞 IsolatedCall: Setting local description (answer)');
    await _peerConnection!.setLocalDescription(answer);
    print('📞 IsolatedCall: Sending answer signal');
    _sendWebRtcSignal({'type': 'answer', 'sdp': answer.sdp});
    print('📞 IsolatedCall: Answer signal sent');
  }

  void _handleAnswer(String? sdp) async {
    print('📞 IsolatedCall: _handleAnswer called');
    if (sdp == null) {
      print('📞 IsolatedCall: ERROR - SDP is null');
      return;
    }
    print('📞 IsolatedCall: Setting remote description (answer)');
    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    print('📞 IsolatedCall: Remote description set successfully');
  }

  void _handleCandidate(Map<String, dynamic> signal) {
    print('📞 IsolatedCall: _handleCandidate called');
    print('📞 IsolatedCall: Candidate data: ${signal['candidate']?.toString().substring(0, 50)}...');
    final candidate = RTCIceCandidate(
      signal['candidate'],
      signal['sdpMid'],
      signal['sdpMLineIndex'],
    );
    print('📞 IsolatedCall: Adding ICE candidate to peer connection');
    _peerConnection!.addCandidate(candidate);
    print('📞 IsolatedCall: ICE candidate added');
  }

  void _sendWebRtcSignal(Map<String, dynamic> signal) {
    final message = {
      'action': 'webrtc_signal',
      'data': {
        ...signal,
        'call_id': _session!.callId,
        'peer_user_id': _peerUserId,
      },
    };
    // Send via the already-configured send channel in CallSignalingService
    CallSignalingService.instance.send(jsonEncode(message));
  }

  void _startRingingFeedback() {
    _ringTimer?.cancel();
    _ringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.heavyImpact();
    });
    HapticFeedback.heavyImpact();
  }

  void _stopRingingFeedback() {
    _ringTimer?.cancel();
  }

  void _startRingingTimeout() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_session?.state == CallState.ringing) {
        CallSignalingService.instance.endCall();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _session != null) {
        setState(() {
          _session = _session!.copyWith(
            durationSeconds: _session!.durationSeconds + 1,
          );
        });
      }
    });
  }

  void _startMaxCallTimer() {
    _maxCallTimer?.cancel();
    _maxCallTimer = Timer(const Duration(minutes: 60), () {
      CallSignalingService.instance.endCall();
    });
  }

  Future<void> _initProximitySensor() async {
    try {
      print('📞 IsolatedCall: Initializing proximity sensor');
      await ProximityWakeLock.acquire();
      print('📞 IsolatedCall: Proximity wake lock acquired');
      
      try {
        _proximitySub = _proximityChannel.receiveBroadcastStream().listen((event) {
          // Handle proximity events
        });
        print('📞 IsolatedCall: Proximity sensor listener started');
      } catch (e) {
        print('📞 IsolatedCall: Proximity sensor channel not available (optional feature) - $e');
        // Proximity sensor is optional, continue without it
      }
    } catch (e) {
      print('📞 IsolatedCall: Proximity wake lock error - $e');
      // Proximity sensor is optional, continue without it
    }
  }

  Future<void> _stopProximitySensorAndRestore() async {
    _proximitySub?.cancel();
    await ProximityWakeLock.release();
  }

  void _cleanupWebRtc() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _acceptCall() {
    print('📞 IsolatedCall: Accepting call');
    CallSignalingService.instance.acceptCall();
  }

  void _rejectCall() {
    print('📞 IsolatedCall: Rejecting call');
    CallSignalingService.instance.rejectCall();
  }

  void _endCall() {
    print('📞 IsolatedCall: Ending call');
    CallSignalingService.instance.endCall();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_localStream != null) {
        _localStream!.getAudioTracks().forEach((track) {
          track.enabled = !_isMuted;
        });
      }
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeaker = !_isSpeaker;
    });
  }

  void _toggleCamera() {
    setState(() {
      _cameraOff = !_cameraOff;
      if (_localStream != null) {
        _localStream!.getVideoTracks().forEach((track) {
          track.enabled = !_cameraOff;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callSubscription?.cancel();
    _durationTimer?.cancel();
    _ringTimer?.cancel();
    _ringingTimeoutTimer?.cancel();
    _maxCallTimer?.cancel();
    _stopRingingFeedback();
    _cleanupWebRtc();
    _stopProximitySensorAndRestore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isVideo ? _buildVideoCall() : _buildVoiceCall(),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _callChannel.invokeMethod('endCall'),
          ),
          Expanded(
            child: Text(
              _session?.state.name.toUpperCase() ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildVoiceCall() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF075E54),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          _session?.peerName ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_session?.state == CallState.ringing)
          const Text(
            'Ringing...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          )
        else if (_session?.state == CallState.connected)
          Text(
            _formatDuration(_session?.durationSeconds ?? 0),
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
      ],
    );
  }

  Widget _buildVideoCall() {
    return Stack(
      children: [
        Positioned.fill(
          child: RTCVideoView(_remoteRenderer),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: SizedBox(
            width: 100,
            height: 150,
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    if (_session?.state == CallState.connected) {
      return _buildActiveControls();
    } else if (_session?.state == CallState.ringing && _session?.direction == CallDirection.incoming) {
      return _buildIncomingControls();
    } else if (_session?.state == CallState.ringing || _session?.state == CallState.dialing) {
      return _buildCallerControls();
    }
    return const SizedBox.shrink();
  }

  Widget _buildCallerControls() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            onTap: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            onTap: _rejectCall,
          ),
          _buildControlButton(
            icon: Icons.call,
            color: Colors.green,
            onTap: _acceptCall,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveControls() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            color: Colors.white.withOpacity(0.2),
            onTap: _toggleMute,
          ),
          if (_isVideo)
            _buildControlButton(
              icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
              color: Colors.white.withOpacity(0.2),
              onTap: _toggleCamera,
            ),
          _buildControlButton(
            icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
            color: Colors.white.withOpacity(0.2),
            onTap: _toggleSpeaker,
          ),
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            onTap: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
