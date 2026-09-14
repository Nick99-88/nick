import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/rtc_room_model.dart';
import '../services/rtc_room_service.dart';
import '../services/call_recording_service.dart';
import '../../native/mic_level_channel.dart';
import '../../video_directory/services/picture_in_picture_service.dart';

class RtcParticipantRoomScreen extends StatefulWidget {
  final String roomId;
  final String? roomPassword;

  const RtcParticipantRoomScreen({
    super.key,
    required this.roomId,
    this.roomPassword,
  });

  @override
  State<RtcParticipantRoomScreen> createState() => _RtcParticipantRoomScreenState();
}

class _RtcParticipantRoomScreenState extends State<RtcParticipantRoomScreen> with WidgetsBindingObserver {
  final _roomService = RtcRoomService();
  WebSocketChannel? _socket;

  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isMicOn = true;
  bool _isCamOn = false;
  bool _connecting = true;

  String _roomName = 'Loading...';
  String _roomType = 'all_speakers_all_videos';
  String _myUserId = '';

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, RtcParticipant> _participants = {};
  final Set<String> _activeSpeakerIds = {};
  String? _pinnedUserId;

  Timer? _vadTimer;
  Timer? _fastLevelTimer;
  Timer? _waveAnimTimer;
  bool _wasTalkingLastFrame = false;
  double _currentAudioLevel = 0.0;
  int _fastLevelSampleCount = 0;
  StreamSubscription? _micDataSubscription;

  double _waveLevel = 0.0;
  List<double> _frequencyBands = List.filled(36, 0.0);
  bool _nativeAnalyzerReady = false;
  final List<double> _smoothedBands = List.filled(36, 0.0);

  final List<_LogEntry> _liveLogs = [];
  final ScrollController _logScrollController = ScrollController();

  // Chat
  final ValueNotifier<List<Map<String, dynamic>>> _chatMessages = ValueNotifier([]);
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Button visibility — participant screen: only mic + cam + end call, no screen share
  bool get _canMic => _roomType != 'one_speaker';
  bool get _canCam => false;
  bool get _canScreenShare => false;

  // Local call recording (saved on device, no server upload)
  final CallRecordingService _recorder = CallRecordingService();
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  int _recordingElapsedMs = 0;
  Timer? _recordingTimer;

  final Map<String, dynamic> _configMap = {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
    'optional': [],
  };

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'turn:openrelay.metered.ca:80', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
      {'urls': 'turn:openrelay.metered.ca:443', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
      {'urls': 'turn:openrelay.metered.ca:443?transport=tcp', 'username': 'openrelayproject', 'credential': 'openrelayproject'},
    ]
  };

  final Map<String, List<Map<String, dynamic>>> _pendingCandidates = {};

  // Reconnection state
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  // PiP state
  final PictureInPictureService _pipService = PictureInPictureService.instance;
  bool _isInPipMode = false;
  StreamSubscription? _pipModeSub;
  StreamSubscription? _userLeaveHintSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pipService.initialize();
    _pipModeSub = _pipService.pipModeChanged.listen((inPip) {
      if (mounted) setState(() => _isInPipMode = inPip);
    });
    _userLeaveHintSub = _pipService.userLeaveHint.listen((_) {
      if (mounted && !_isInPipMode && _socket != null) {
        _pipService.enterPip();
      }
    });
    _initAndJoin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pipModeSub?.cancel();
    _userLeaveHintSub?.cancel();
    _pipService.setInRtcRoom(false);
    _vadTimer?.cancel();
    _fastLevelTimer?.cancel();
    _waveAnimTimer?.cancel();
    _micDataSubscription?.cancel();
    _recordingTimer?.cancel();
    if (_isRecording) {
      _recorder.stop().catchError((_) {});
    }
    _logScrollController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    _wasTalkingLastFrame = false;
    _cleanup();
    super.dispose();
  }

  Future<void> _cleanup() async {
    MicLevelChannel.instance.stop();
    _socket?.sink.close();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localRenderer.dispose();
    _peerConnections.forEach((_, pc) => pc.close());
    _peerConnections.clear();
    _remoteRenderers.forEach((_, r) => r.dispose());
    _remoteRenderers.clear();
    _pendingCandidates.clear();
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final ts = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() => _liveLogs.add(_LogEntry(timestamp: ts, message: message)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(_logScrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _socket == null && !_isReconnecting && mounted) {
      debugPrint('📱 App resumed — attempting WebSocket reconnect');
      _reconnectWebSocket();
    }
  }

  Future<void> _reconnectWebSocket() async {
    if (_isReconnecting || !mounted) return;
    _isReconnecting = true;
    _addLog('Reconnecting to server...');

    while (_reconnectAttempts < _maxReconnectAttempts && mounted) {
      _reconnectAttempts++;
      try {
        final wsUrl = await _roomService.getSignalingUrl(widget.roomId, roomPassword: widget.roomPassword);
        _socket = WebSocketChannel.connect(Uri.parse(wsUrl));
        _socket!.stream.listen(
          (msg) {
            _reconnectAttempts = 0;
            _handleSignalingMessage(jsonDecode(msg));
          },
          onDone: () {
            _socket = null;
            if (mounted && !_isReconnecting) {
              _addLog('Connection lost — reconnecting...');
              _reconnectWebSocket();
            }
          },
          onError: (e) {
            _socket = null;
            if (mounted && !_isReconnecting) {
              _reconnectWebSocket();
            }
          },
        );
        _addLog('Reconnected successfully');
        _sendMediaState();
        _startLocalVadMonitor();
        _isReconnecting = false;
        return;
      } catch (e) {
        debugPrint('Reconnect attempt $_reconnectAttempts failed: $e');
        await Future.delayed(Duration(seconds: _reconnectAttempts * 2));
      }
    }
    _isReconnecting = false;
    if (mounted) _showErrorAndExit('Failed to reconnect after $_maxReconnectAttempts attempts.');
  }

  Future<void> _initAndJoin() async {
    final granted = await _requestPermissions();
    if (!granted) {
      _showErrorAndExit('Camera and Microphone permissions are required.');
      return;
    }
    await _localRenderer.initialize();

    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user', 'width': '640', 'height': '480'}
      });
      _localRenderer.srcObject = _localStream;
      _localStream!.getVideoTracks().forEach((t) => t.enabled = _isCamOn);
      _localStream!.getAudioTracks().forEach((t) => t.enabled = _isMicOn);
    } catch (e) {
      debugPrint('Error getting full media: $e (trying audio-only)');
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
        _localRenderer.srcObject = _localStream;
        _localStream!.getAudioTracks().forEach((t) => t.enabled = _isMicOn);
      } catch (e2) {
        debugPrint('Error getting audio only: $e2');
      }
    }

    try {
      final wsUrl = await _roomService.getSignalingUrl(widget.roomId, roomPassword: widget.roomPassword);
      _socket = WebSocketChannel.connect(Uri.parse(wsUrl));
      _socket!.stream.listen(
        (msg) => _handleSignalingMessage(jsonDecode(msg)),
        onDone: () {
          _socket = null;
          if (mounted) {
            _addLog('Connection lost — reconnecting...');
            _reconnectWebSocket();
          }
        },
        onError: (e) {
          _socket = null;
          if (mounted) {
            _reconnectWebSocket();
          }
        },
      );
    } catch (e) {
      _showErrorAndExit('Failed to initialize signaling: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    return statuses[Permission.camera]!.isGranted && statuses[Permission.microphone]!.isGranted;
  }

  void _showErrorAndExit(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    Navigator.pop(context);
  }

  Future<void> _startLocalVadMonitor() async {
    _vadTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _sendAudioLevelToServer());
    _fastLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _readFastLevel());
    _startWaveAnimation();
    MicLevelChannel.instance.start();
  }

  Future<void> _sendAudioLevelToServer() async {
    if (_localStream == null || _socket == null || !_isMicOn) return;
    double level = MicLevelChannel.instance.currentLevel;
    if (level <= 0) {
      for (final entry in _peerConnections.entries) {
        try {
          final reports = await entry.value.getStats();
          for (final report in reports) {
            if (report.type == 'outbound-rtp' && report.values['kind'] == 'audio') {
              final lvl = report.values['audioLevel'];
              if (lvl != null) {
                level = double.tryParse(lvl.toString()) ?? 0.0;
                if (level > 0) break;
              }
            }
          }
        } catch (_) {}
        if (level > 0) break;
      }
    }
    _socket?.sink.add(jsonEncode({'type': 'audio_level', 'level': level}));
  }

  Future<void> _readFastLevel() async {
    if (_localStream == null) return;
    double level = MicLevelChannel.instance.currentLevel;
    if (level <= 0) {
      final tracks = _localStream!.getAudioTracks();
      level = (_isMicOn && tracks.isNotEmpty && tracks.first.enabled) ? 0.3 : 0.0;
    }
    setState(() => _currentAudioLevel = level);
    _fastLevelSampleCount++;
  }

  void _startWaveAnimation() {
    _micDataSubscription = MicLevelChannel.instance.onData.listen((data) {
      if (!mounted) return;
      if (data.bands.isNotEmpty) {
        _nativeAnalyzerReady = true;
        setState(() {
          _frequencyBands = data.bands;
          const double smoothing = 0.25;
          double maxBand = 0.0;
          for (int i = 0; i < _frequencyBands.length && i < 36; i++) {
            final raw = _frequencyBands[i].clamp(0.0, 1.0);
            _smoothedBands[i] += (raw - _smoothedBands[i]) * smoothing;
            if (_smoothedBands[i] > maxBand) maxBand = _smoothedBands[i];
          }
          _waveLevel += (maxBand - _waveLevel) * 0.15;
        });
      }
    });

    _waveAnimTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_nativeAnalyzerReady) return;
      setState(() {
        final target = (_activeSpeakerIds.isNotEmpty || _wasTalkingLastFrame)
            ? _currentAudioLevel.clamp(0.3, 1.0) : 0.0;
        _waveLevel += (target - _waveLevel) * 0.12;
        _waveLevel = _waveLevel.clamp(0.0, 1.0);
      });
    });
  }

  void _handleSignalingMessage(Map<String, dynamic> data) async {
    final type = data['type'];
    switch (type) {
      case 'room_state':
        for (final pc in _peerConnections.values) {
          try { pc.close(); } catch (_) {}
        }
        _peerConnections.clear();
        for (final r in _remoteRenderers.values) {
          try { r.dispose(); } catch (_) {}
        }
        _remoteRenderers.clear();
        _pendingCandidates.clear();
        setState(() {
          _roomName = data['name'] ?? 'Room';
          _roomType = data['room_type'] ?? 'all_speakers_all_videos';
          _myUserId = data['my_user_id'] ?? '';
          _connecting = false;
        });
        final others = data['participants'] ?? [];
        for (final p in others) {
          final part = RtcParticipant.fromJson(p);
          setState(() => _participants[part.userId] = part);
          await _createPeerConnection(part.userId, isOffer: true);
        }
        _startLocalVadMonitor();
        _sendMediaState();
        _pipService.setInRtcRoom(true);
        _addLog('You joined the room');
        for (final p in others) {
          final name = (p['name'] as String?) ?? 'User';
          _addLog('$name is in the room');
        }
        break;

      case 'user_joined':
        final part = RtcParticipant.fromJson(data['participant']);
        setState(() => _participants[part.userId] = part);
        _addLog('${part.name} joined the room');
        break;

      case 'user_left':
        final leaveId = data['user_id'];
        final leaveName = _participants[leaveId]?.name ?? 'User';
        setState(() { _participants.remove(leaveId); _activeSpeakerIds.remove(leaveId); });
        _addLog('$leaveName left the room');
        _peerConnections[leaveId]?.close();
        _peerConnections.remove(leaveId);
        _remoteRenderers[leaveId]?.dispose();
        _remoteRenderers.remove(leaveId);
        _pendingCandidates.remove(leaveId);
        break;

      case 'signal':
        final senderId = data['sender_id'];
        final signal = data['signal'];
        if (signal['type'] == 'offer') {
          final pc = await _createPeerConnection(senderId, isOffer: false);
          await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'], 'offer'));
          final answer = await pc.createAnswer(_configMap);
          await pc.setLocalDescription(answer);
          _socket?.sink.add(jsonEncode({'type': 'signal', 'target_id': senderId, 'signal': {'type': 'answer', 'sdp': answer.sdp}}));
        } else if (signal['type'] == 'answer') {
          final pc = _peerConnections[senderId];
          if (pc != null) await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'], 'answer'));
        } else if (signal['type'] == 'candidate') {
          final pc = _peerConnections[senderId];
          if (pc != null) {
            await pc.addCandidate(RTCIceCandidate(signal['candidate'], signal['sdpMid'], signal['sdpMLineIndex']));
          } else {
            _pendingCandidates.putIfAbsent(senderId, () => []).add({'candidate': signal['candidate'], 'sdpMid': signal['sdpMid'], 'sdpMLineIndex': signal['sdpMLineIndex']});
          }
        }
        break;

      case 'active_speakers':
        final List<dynamic> speakerList = data['user_ids'] ?? [];
        setState(() {
          _activeSpeakerIds.clear();
          for (final id in speakerList) { if (id is String) _activeSpeakerIds.add(id); }
          _wasTalkingLastFrame = _activeSpeakerIds.contains(_myUserId);
        });
        break;

      case 'media_state_changed':
        final uId = data['user_id'];
        setState(() {
          if (_participants.containsKey(uId)) {
            _participants[uId]!.camera = data['camera'] ?? false;
            _participants[uId]!.mic = data['mic'] ?? true;
          }
        });
        break;

      case 'moderator_action':
        final action = data['action'];
        final senderName = data['sender_name'] ?? 'Host';
        if (action == 'mute') {
          setState(() => _isMicOn = false);
          _localStream?.getAudioTracks().forEach((t) => t.enabled = false);
          _sendMediaState();
          _addLog('You were muted by $senderName');
        } else if (action == 'stop_video') {
          setState(() => _isCamOn = false);
          _localStream?.getVideoTracks().forEach((t) => t.enabled = false);
          _sendMediaState();
          _addLog('Your camera was stopped by $senderName');
        }
        break;

      case 'kicked':
        _addLog('You were kicked out');
        _showErrorAndExit('You have been kicked out by the Host.');
        break;

      case 'room_terminated':
        _addLog('Room was ended by host');
        _showErrorAndExit(data['message'] ?? 'Room closed by Host.');
        break;

      case 'chat_message':
        if (data['sender_id'] == _myUserId) break;
        _chatMessages.value = [..._chatMessages.value, {
          'sender_id': data['sender_id'],
          'sender_name': data['sender_name'] ?? 'User',
          'text': data['text'] ?? '',
          'timestamp': data['timestamp'] ?? '',
        }];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollController.hasClients) {
            _chatScrollController.animateTo(_chatScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
          }
        });
        break;
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String peerId, {required bool isOffer}) async {
    final pc = await createPeerConnection(_iceServers, _configMap);
    _peerConnections[peerId] = pc;

    if (_localStream != null) {
      _localStream!.getTracks().forEach((t) => pc.addTrack(t, _localStream!));
    }

    pc.onIceCandidate = (RTCIceCandidate c) {
      if (c.candidate == null || c.candidate!.isEmpty) return;
      _socket?.sink.add(jsonEncode({
        'type': 'signal', 'target_id': peerId,
        'signal': {'type': 'candidate', 'candidate': c.candidate, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex}
      }));
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('🔄 ICE state [$peerId]: $state');
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        final stream = event.streams[0];
        final renderer = RTCVideoRenderer();
        renderer.initialize().then((_) {
          renderer.srcObject = stream;
          setState(() => _remoteRenderers[peerId] = renderer);
        }).catchError((e) { renderer.dispose(); });
      }
    };

    if (isOffer) {
      final offer = await pc.createOffer(_configMap);
      await pc.setLocalDescription(offer);
      _socket?.sink.add(jsonEncode({'type': 'signal', 'target_id': peerId, 'signal': {'type': 'offer', 'sdp': offer.sdp}}));
    }

    final pending = _pendingCandidates.remove(peerId);
    if (pending != null) {
      for (final c in pending) {
        try { await pc.addCandidate(RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex'])); } catch (_) {}
      }
    }

    return pc;
  }

  void _toggleMic() {
    if (_roomType == 'one_speaker') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only the host can speak in this room.')));
      return;
    }
    setState(() => _isMicOn = !_isMicOn);
    _localStream?.getAudioTracks().forEach((t) => t.enabled = _isMicOn);
    _sendMediaState();
  }

  void _toggleCam() {
    final hostOnly = _roomType == 'one_video' || _roomType == 'all_speakers_one_video';
    if (hostOnly) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only the host can stream video.')));
      return;
    }
    setState(() => _isCamOn = !_isCamOn);
    _localStream?.getVideoTracks().forEach((t) => t.enabled = _isCamOn);
    _sendMediaState();
  }

  void _sendMediaState() {
    _socket?.sink.add(jsonEncode({'type': 'media_state', 'camera': _isCamOn, 'mic': _isMicOn}));
  }

  // ── Chat ──
  void _sendChatMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty || _socket == null) return;
    _chatMessages.value = [..._chatMessages.value, {
      'sender_id': _myUserId,
      'sender_name': 'You',
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    }];
    _socket!.sink.add(jsonEncode({'type': 'chat_message', 'text': text}));
    _chatInputController.clear();
  }

  void _showChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B3A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Room Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 8),
            SizedBox(height: 300, child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _chatMessages,
              builder: (ctx, msgs, _) {
                if (msgs.isEmpty) {
                  return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.white38)));
                }
                return ListView.builder(
                  controller: _chatScrollController, padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final isMe = msg['sender_id'] == _myUserId;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.deepPurpleAccent.withValues(alpha: 0.4) : Colors.white10,
                          borderRadius: BorderRadius.circular(12)),
                        child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                          if (!isMe) Text(msg['sender_name'] ?? 'User',
                            style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ]),
                      ),
                    );
                  },
                );
              },
            )),
            Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              Expanded(child: TextField(
                controller: _chatInputController, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...', hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  filled: true, fillColor: Colors.white10,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                onSubmitted: (_) => _sendChatMessage())),
              const SizedBox(width: 8),
              IconButton(onPressed: _sendChatMessage, icon: const Icon(Icons.send, color: Colors.deepPurpleAccent)),
            ])),
          ])),
        );
      },
    );
  }

  // ── Local call recording ──
  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRecordingPaused && mounted) {
        setState(() => _recordingElapsedMs += 1000);
      }
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) return;
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      _addLog('Recording needs microphone permission');
      return;
    }
    try {
      await _recorder.start(
        roomId: widget.roomId,
        roomName: _roomName,
        recorderName: _participants[_myUserId]?.name ?? 'You',
      );
      setState(() {
        _isRecording = true;
        _isRecordingPaused = false;
        _recordingElapsedMs = 0;
      });
      _startRecordingTimer();
      _addLog('Recording started');
    } catch (e) {
      debugPrint('Recording start failed: $e');
      _addLog('Recording failed to start');
    }
  }

  Future<void> _pauseResumeRecording() async {
    if (!_isRecording) return;
    try {
      if (_isRecordingPaused) {
        await _recorder.resume();
        setState(() => _isRecordingPaused = false);
        _addLog('Recording resumed');
      } else {
        await _recorder.pause();
        setState(() => _isRecordingPaused = true);
        _addLog('Recording paused');
      }
    } catch (e) {
      debugPrint('Recording pause/resume failed: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      final entry = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
      });
      _addLog('Recording saved to this device');
      if (entry != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording saved (${formatRecordingDuration(entry.durationMs)})')),
        );
      }
    } catch (e) {
      debugPrint('Recording stop failed: $e');
      if (mounted) setState(() {
        _isRecording = false;
        _isRecordingPaused = false;
      });
    }
  }

  Widget _buildRecordingBar() {
    if (!_isRecording) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isRecordingPaused ? Colors.amber : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isRecordingPaused ? 'Paused' : formatRecordingDuration(_recordingElapsedMs),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _pauseResumeRecording,
            child: Icon(
              _isRecordingPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _stopRecording,
            child: const Icon(Icons.stop, color: Colors.red, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingPill() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.red, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: _isRecordingPaused ? Colors.amber : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isRecordingPaused ? 'Paused' : formatRecordingDuration(_recordingElapsedMs),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pauseResumeRecording,
            child: SizedBox(
              width: 40, height: 40,
              child: Icon(
                _isRecordingPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _stopRecording,
            child: const SizedBox(
              width: 40, height: 40,
              child: Icon(Icons.stop, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveRoom() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Room?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type the room ID to confirm:'),
            const SizedBox(height: 4),
            Text(widget.roomId, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(controller: controller, decoration: InputDecoration(
              hintText: 'Enter room ID', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().toUpperCase() == widget.roomId.toUpperCase()) {
                Navigator.pop(ctx); Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room ID does not match.')));
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInPipMode) return _buildPipView();
    if (_connecting) {
      return const Scaffold(body: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Connecting to room...', style: TextStyle(color: Colors.grey))],
      )));
    }

    final hasRemote = _remoteRenderers.isNotEmpty;
    final speakerIds = _activeSpeakerIds.where((id) => _remoteRenderers.containsKey(id)).toList();
    final List<String> displayIds;
    if (_pinnedUserId != null && _remoteRenderers.containsKey(_pinnedUserId)) {
      displayIds = [_pinnedUserId!];
    } else {
      displayIds = speakerIds.isNotEmpty ? speakerIds : (hasRemote ? [_remoteRenderers.keys.first] : <String>[]);
    }
    final pipIds = <String>[];
    if (hasRemote) {
      for (final id in _remoteRenderers.keys) {
        if (!displayIds.contains(id)) pipIds.add(id);
      }
    }
    final displayKey = ValueKey(displayIds.join(','));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      body: Stack(children: [
        Positioned.fill(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)), child: child)),
          child: _buildMainArea(displayIds, key: displayKey),
        )),
        if (_waveLevel > 0.05) Positioned(left: 0, right: 0, bottom: 165, child: _buildVoiceWaves()),
        Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
        if (hasRemote) Positioned(left: 0, right: 0, bottom: 90,
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: _buildPipStrip(pipIds, key: ValueKey(pipIds.join(','))))),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildControlBar()),
      ]),
    );
  }

  Widget _buildMainArea(List<String> displayIds, {Key? key}) {
    return Container(key: key, color: const Color(0xFF111018),
      child: displayIds.isEmpty
          ? _buildVideoTile('You', _localRenderer, true, _isCamOn, _isMicOn, true)
          : displayIds.length == 1
              ? _buildVideoTile(_participants[displayIds.first]?.name ?? 'Participant', _remoteRenderers[displayIds.first], false, _participants[displayIds.first]?.camera ?? false, _participants[displayIds.first]?.mic ?? true, false, pinned: _pinnedUserId == displayIds.first, userId: displayIds.first)
              : _buildMultiSpeakerGrid(displayIds),
    );
  }

  Widget _buildMultiSpeakerGrid(List<String> ids) {
    final cols = ids.length <= 2 ? 1 : 2;
    return LayoutBuilder(builder: (context, constraints) {
      return Column(children: List.generate((ids.length / cols).ceil(), (rowIndex) {
        final start = rowIndex * cols;
        final end = (start + cols).clamp(0, ids.length);
        final rowItems = ids.sublist(start, end);
        return Expanded(child: Row(children: rowItems.map((id) {
          return Expanded(child: Padding(
            padding: EdgeInsets.all(rowItems.length > 1 ? 1.5 : 0),
            child: _AnimatedTile(child: _buildVideoTile(_participants[id]?.name ?? 'Participant', _remoteRenderers[id], false, _participants[id]?.camera ?? false, _participants[id]?.mic ?? true, false, pinned: _pinnedUserId == id, userId: id)),
          ));
        }).toList()));
      }));
    });
  }

  Widget _buildVideoTile(String name, RTCVideoRenderer? renderer, bool isLocal, bool cameraOn, bool micOn, bool isLocalTile, {bool pinned = false, String? userId}) {
    final hasVideo = isLocalTile ? _isCamOn : (renderer != null && cameraOn);
    final isSpeaking = isLocalTile ? _wasTalkingLastFrame : (userId != null && _activeSpeakerIds.contains(userId));

    return Container(color: const Color(0xFF1E1B3A), child: Stack(children: [
      if (hasVideo && renderer != null) RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: isLocal)
      else Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: isLocalTile ? 100 : 60, height: isLocalTile ? 100 : 60,
          decoration: BoxDecoration(color: Colors.deepPurpleAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(fontSize: isLocalTile ? 40 : 24, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)))),
        const SizedBox(height: 8),
        Text(isLocalTile ? 'You' : name, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        if (!isLocalTile) const Text('Camera off', style: TextStyle(color: Colors.white38, fontSize: 10)),
      ])),
      if (pinned) Positioned(top: 8, left: 8, child: Container(width: 24, height: 24,
        decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
        child: const Icon(Icons.push_pin, size: 14, color: Colors.black87))),
      Positioned(top: 8, right: 8, child: Container(width: 24, height: 24,
        decoration: BoxDecoration(color: micOn ? Colors.green : Colors.red, shape: BoxShape.circle),
        child: Icon(micOn ? Icons.mic : Icons.mic_off, size: 14, color: Colors.white))),
      Positioned(bottom: 8, left: 8, right: 8, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(isLocalTile ? 'You' : name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
          if (isSpeaking) const Icon(Icons.graphic_eq, color: Colors.greenAccent, size: 12),
        ]),
      )),
    ]));
  }

  Widget _buildVoiceWaves() {
    final bands = _nativeAnalyzerReady ? _smoothedBands : List<double>.filled(36, 0);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_activeSpeakerIds.isNotEmpty) Text(
        _activeSpeakerIds.length == 1 ? (_participants[_activeSpeakerIds.first]?.name ?? 'Speaking') : '${_activeSpeakerIds.length} people speaking',
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      SizedBox(height: 24, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(36, (i) {
        double rawHeight;
        if (_nativeAnalyzerReady) { rawHeight = bands[i] * 20.0 + 3.0; }
        else { rawHeight = _waveLevel * ((i % 5) / 5.0) * 20.0 + 3.0; }
        final barH = rawHeight.clamp(3.0, 23.0);
        return Container(width: 3, height: barH, margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(color: Colors.deepPurpleAccent.withValues(alpha: 0.5 + (barH / 23.0) * 0.5), borderRadius: BorderRadius.circular(2)));
      }))),
    ]);
  }

  Widget _buildTopBar() {
    return SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Container(
          height: 28, margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
          child: _liveLogs.isEmpty
              ? const Center(child: Text('No activity yet', style: TextStyle(color: Colors.white24, fontSize: 9)))
              : ListView.builder(
                  controller: _logScrollController, padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _liveLogs.length,
                  itemBuilder: (_, i) {
                    final log = _liveLogs[i];
                    return Text('${log.timestamp} ${log.message}', style: const TextStyle(color: Colors.white60, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis);
                  }),
        )),
        Column(children: [
          Text(_roomName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          Text('Room: ${widget.roomId}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
        const SizedBox(width: 28),
      ]),
    ));
  }

  Widget _buildPipStrip(List<String> pipIds, {Key? key}) {
    if (pipIds.isEmpty) return const SizedBox.shrink(key: ValueKey('empty_pip'));
    return SizedBox(key: key, height: 90, child: ListView.builder(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: pipIds.length,
      itemBuilder: (context, index) {
        final id = pipIds[index];
        final renderer = _remoteRenderers[id];
        final part = _participants[id];
        final name = part?.name ?? 'User';
        final hasVideo = renderer != null && (part?.camera ?? false);
        final isPinned = _pinnedUserId == id;
        return _AnimatedTile(child: GestureDetector(
          onTap: () => setState(() => _pinnedUserId = isPinned ? null : id),
          child: Container(width: 80, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B3A), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isPinned ? Colors.amber : _activeSpeakerIds.contains(id) ? Colors.deepPurpleAccent : Colors.transparent, width: 2)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              if (hasVideo) RTCVideoView(renderer!, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              else Center(child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 18))),
              Positioned(bottom: 2, left: 2, right: 2, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 8), overflow: TextOverflow.ellipsis)),
                  if (_activeSpeakerIds.contains(id)) const Padding(padding: EdgeInsets.only(left: 2), child: Icon(Icons.graphic_eq, color: Colors.greenAccent, size: 8)),
                ]),
              )),
              Positioned(top: 4, right: 4, child: Container(width: 16, height: 16,
                decoration: BoxDecoration(color: (part?.mic ?? true) ? Colors.green : Colors.red, shape: BoxShape.circle),
                child: Icon((part?.mic ?? true) ? Icons.mic : Icons.mic_off, size: 10, color: Colors.white))),
            ]),
          ),
        ));
      },
    ));
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF0F0C20)])),
      child: SafeArea(top: false, child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _ctrlBtn(_isMicOn ? Icons.mic : Icons.mic_off, _isMicOn ? Colors.deepPurpleAccent : Colors.red, _toggleMic),
          const SizedBox(width: 10),
          _ctrlBtn(Icons.chat_bubble_outline, Colors.deepPurpleAccent, _showChatSheet),
          const SizedBox(width: 10),
          _ctrlBtn(Icons.call_end, Colors.red, _confirmLeaveRoom, size: 56),
          const SizedBox(width: 10),
          if (_isRecording)
            _buildRecordingPill()
          else
            _ctrlBtn(Icons.radio_button_off, Colors.deepPurpleAccent, _toggleRecording),
          const SizedBox(width: 10),
          if (_canCam)
            _ctrlBtn(_isCamOn ? Icons.videocam : Icons.videocam_off, _isCamOn ? Colors.deepPurpleAccent : Colors.red, _toggleCam),
        ]),
      )),
    );
  }

  Widget _ctrlBtn(IconData icon, Color color, VoidCallback onTap, {double size = 52}) {
    return GestureDetector(onTap: onTap, child: Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    ));
  }

  Widget _buildPipView() {
    final hasRemote = _remoteRenderers.isNotEmpty;
    final speakerIds = _activeSpeakerIds.where((id) => _remoteRenderers.containsKey(id)).toList();
    final String? mainId;
    if (_pinnedUserId != null && _remoteRenderers.containsKey(_pinnedUserId)) {
      mainId = _pinnedUserId;
    } else if (speakerIds.isNotEmpty) {
      mainId = speakerIds.first;
    } else if (hasRemote) {
      mainId = _remoteRenderers.keys.first;
    } else {
      mainId = null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C20),
      body: Stack(
        children: [
          Positioned.fill(
            child: mainId != null
                ? RTCVideoView(
                    _remoteRenderers[mainId]!,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : (_isCamOn && _localStream != null
                    ? RTCVideoView(_localRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover, mirror: true)
                    : Center(
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: Colors.deepPurpleAccent.withValues(alpha: 0.3), shape: BoxShape.circle),
                          child: const Center(child: Icon(Icons.mic, color: Colors.deepPurpleAccent, size: 36)),
                        ),
                      )),
          ),
          Positioned(
            bottom: 4, left: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(_roomName, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                  Text('${_participants.length + 1}', style: const TextStyle(color: Colors.white70, fontSize: 9)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry {
  final String timestamp;
  final String message;
  const _LogEntry({required this.timestamp, required this.message});
}

class _AnimatedTile extends StatefulWidget {
  final Widget child;
  const _AnimatedTile({required this.child});
  @override
  State<_AnimatedTile> createState() => _AnimatedTileState();
}

class _AnimatedTileState extends State<_AnimatedTile> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _ctrl.forward(from: 0.0);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _fadeAnim, child: ScaleTransition(scale: _scaleAnim, child: widget.child));
}
