import 'dart:async';
import 'dart:convert';
import '../../services/socket/enhanced_socket_service.dart';
import '../../chat_local_db/chat_local_db.dart';
import 'socket_event_bus.dart';
import 'call_kit_service.dart';
import 'call_foreground_service.dart';

enum CallType { voice, video }
enum CallState { idle, dialing, ringing, connected, busy, rejected, missed, ended }
enum CallDirection { outgoing, incoming }

class CallSession {
  final String callId;
  final String peerUserId;
  final String peerPhone;
  final String peerName;
  final String peerAvatar;
  final CallType type;
  final CallState state;
  final CallDirection direction;
  final DateTime startTime;
  DateTime? connectedTime;
  DateTime? endTime;
  int durationSeconds = 0;

  CallSession({
    required this.callId,
    required this.peerUserId,
    required this.peerPhone,
    required this.peerName,
    this.peerAvatar = '',
    required this.type,
    required this.state,
    required this.direction,
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  CallSession copyWith({
    String? callId,
    String? peerUserId,
    String? peerPhone,
    String? peerName,
    String? peerAvatar,
    CallType? type,
    CallState? state,
    CallDirection? direction,
    DateTime? startTime,
    DateTime? connectedTime,
    DateTime? endTime,
    int? durationSeconds,
  }) {
    return CallSession(
      callId: callId ?? this.callId,
      peerUserId: peerUserId ?? this.peerUserId,
      peerPhone: peerPhone ?? this.peerPhone,
      peerName: peerName ?? this.peerName,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      type: type ?? this.type,
      state: state ?? this.state,
      direction: direction ?? this.direction,
      startTime: startTime ?? this.startTime,
    )
      ..connectedTime = connectedTime ?? this.connectedTime
      ..endTime = endTime ?? this.endTime
      ..durationSeconds = durationSeconds ?? this.durationSeconds;
  }

  String get durationFormatted {
    if (connectedTime == null) return '0:00';
    final end = endTime ?? DateTime.now();
    final diff = end.difference(connectedTime!).inSeconds;
    final minutes = diff ~/ 60;
    final seconds = diff % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class CallSignalingService {
  static final CallSignalingService instance = CallSignalingService._init();
  CallSignalingService._init();

  CallSession? _activeCall;
  CallSession? get activeCall => _activeCall;

  Future<void> Function(String)? _sendViaChatChannel;

  void setSendViaChatChannel(Future<void> Function(String)? fn) {
    _sendViaChatChannel = fn;
  }

  bool get isInCall => _activeCall != null && 
      (_activeCall!.state == CallState.dialing || 
       _activeCall!.state == CallState.ringing || 
       _activeCall!.state == CallState.connected);

  void setActiveSession(CallSession session) {
    _activeCall = session;
    _emitState();
  }

  Future<void> send(String json) async {
    print('📞 Call: send called with json: ${json.length} chars');
    for (int i = 0; i < 10; i++) {
      if (_sendViaChatChannel != null) {
        print('📞 Call: Using sendViaChatChannel callback (attempt ${i + 1})');
        await _sendViaChatChannel!(json);
        print('📞 Call: Message sent via callback');
        return;
      }
      if (EnhancedSocketService.isConnected()) {
        print('📞 Call: Using EnhancedSocketService directly (attempt ${i + 1})');
        EnhancedSocketService.sendRawMessage(json);
        print('📞 Call: Message sent via EnhancedSocketService');
        return;
      }
      if (i == 0) {
        print('📞 Call: Socket not connected, triggering connection...');
        await EnhancedSocketService.connect(source: 'CallSignalingService');
      }
      if (!EnhancedSocketService.isConnected()) {
        print('📞 Call: No socket connected, retrying in 1s (attempt ${i + 1}/10)');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    print('📞 Call: Failed to send after 10 attempts');
  }

  final StreamController<CallSession> _callStateController = StreamController<CallSession>.broadcast();
  Stream<CallSession> get callStateStream => _callStateController.stream;

  void initialize() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    SocketEventBus.instance.subscribe('call_incoming', (data) {
      _handleIncomingCall(data);
    });

    SocketEventBus.instance.subscribe('call_accepted', (data) {
      _handleCallAccepted(data);
    });

    SocketEventBus.instance.subscribe('call_rejected', (data) {
      _handleCallRejected(data);
    });

    SocketEventBus.instance.subscribe('call_busy', (data) {
      _handleCallBusy(data);
    });

    SocketEventBus.instance.subscribe('call_ended', (data) {
      _handleCallEnded(data);
    });

    SocketEventBus.instance.subscribe('call_missed', (data) {
      _handleCallMissed(data);
    });

    SocketEventBus.instance.subscribe('call_error', (data) {
      _handleCallError(data);
    });

    SocketEventBus.instance.subscribe('webrtc_signal', (data) {
      _handleWebRtcSignal(data);
    });
  }

  void Function(Map<String, dynamic>)? _onWebRtcSignal;
  Map<String, dynamic>? _pendingWebRtcSignal;

  void Function(Map<String, dynamic>)? get onWebRtcSignal => _onWebRtcSignal;
  set onWebRtcSignal(void Function(Map<String, dynamic>)? callback) {
    _onWebRtcSignal = callback;
    if (callback != null && _pendingWebRtcSignal != null) {
      final signal = _pendingWebRtcSignal!;
      _pendingWebRtcSignal = null;
      callback(signal);
    }
  }

  void _handleWebRtcSignal(Map<String, dynamic> data) {
    print('📞 Call: Received WebRTC signal from ${data['sender_id']}');
    if (_onWebRtcSignal != null) {
      _onWebRtcSignal!(data);
    } else {
      print('📞 Call: Buffering WebRTC signal (onWebRtcSignal not yet set)');
      _pendingWebRtcSignal = data;
    }
  }

  void sendWebRtcSignal(String targetId, String callId, Map<String, dynamic> signal) {
    final message = {
      "action": "webrtc_signal",
      "data": {
        "target_id": targetId,
        "call_id": callId,
        "signal": signal,
      }
    };
    unawaited(send(jsonEncode(message)));
    print('📞 Call: Sent WebRTC signal to $targetId (${signal['type']})');
  }

  Future<void> _saveCallLog(CallState state) async {
    if (_activeCall == null) return;
    try {
      final log = LocalCallLog(
        peerUserId: _activeCall!.peerUserId,
        peerName: _activeCall!.peerName,
        peerAvatar: _activeCall!.peerAvatar,
        callType: _activeCall!.type.name,
        callDirection: _activeCall!.direction.name,
        callState: state.name,
        duration: _activeCall!.durationSeconds,
        callId: _activeCall!.callId,
        isSelf: _activeCall!.direction == CallDirection.outgoing,
      );
      await CallLogRepository().insertOrUpdateCallLog(log);
    } catch (e) {
      print('📞 Call: Error saving call log - $e');
    }
  }

  Future<void> startCall({
    required String peerUserId,
    required String peerPhone,
    required String peerName,
    String peerAvatar = '',
    required CallType type,
  }) async {
    if (isInCall) {
      print('📞 Call: Already in a call');
      return;
    }

    final callId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeCall = CallSession(
      callId: callId,
      peerUserId: peerUserId,
      peerPhone: peerPhone,
      peerName: peerName,
      peerAvatar: peerAvatar,
      type: type,
      state: CallState.dialing,
      direction: CallDirection.outgoing,
    );

    _emitState();

    // Start foreground service to keep WebSocket alive
    await CallForegroundService.instance.startService();

    // Save outgoing call log (isSelf = true for outgoing)
    _saveCallLog(CallState.dialing);

    final message = {
      "action": "call_start",
      "data": {
        "call_id": callId,
        "peer_user_id": peerUserId,
        "peer_phone": peerPhone,
        "call_type": type.name,
        "direction": "outgoing",
        "timestamp": DateTime.now().toIso8601String(),
      }
    };

    await send(jsonEncode(message));
    print('📞 Call: Starting $type call to $peerName ($peerPhone)');
  }

  Future<void> acceptCall() async {
    print('📞 Call: acceptCall called');
    if (_activeCall == null) {
      print('📞 Call: ERROR - No active call to accept');
      return;
    }

    print('📞 Call: Accepting call - callId: ${_activeCall!.callId}, peer: ${_activeCall!.peerName}, current state: ${_activeCall!.state}');

    _activeCall = _activeCall!.copyWith(
      state: CallState.connected,
      connectedTime: DateTime.now(),
    );

    print('📞 Call: State updated to connected, emitting state');
    _emitState();

    // Start foreground service to keep WebSocket alive
    print('📞 Call: Starting foreground service');
    await CallForegroundService.instance.startService();

    print('📞 Call: Reporting call connected to CallKit');
    CallKitService.instance.reportCallConnected(_activeCall!.callId);
    print('📞 Call: Hiding incoming call UI from CallKit');
    CallKitService.instance.hideIncomingCall(_activeCall!.callId);

    final message = {
      "action": "call_accepted",
      "data": {
        "call_id": _activeCall!.callId,
        "peer_user_id": _activeCall!.peerUserId,
        "timestamp": DateTime.now().toIso8601String(),
      }
    };

    print('📞 Call: Sending call_accepted message to peer');
    await send(jsonEncode(message));
    print('📞 Call: Accepted call ${_activeCall!.callId} successfully');
  }

  Future<void> rejectCall() async {
    print('📞 Call: rejectCall called');
    if (_activeCall == null) {
      print('📞 Call: ERROR - No active call to reject');
      return;
    }

    final callId = _activeCall!.callId;
    final peerUserId = _activeCall!.peerUserId;

    print('📞 Call: Rejecting call - callId: $callId, peer: ${_activeCall!.peerName}');

    _activeCall = _activeCall!.copyWith(
      state: CallState.rejected,
      endTime: DateTime.now(),
    );

    print('📞 Call: State updated to rejected, saving call log');
    await _saveCallLog(CallState.rejected);
    print('📞 Call: Emitting state change');
    _emitState();

    print('📞 Call: Ending call in CallKit');
    CallKitService.instance.endCall(callId);

    final message = {
      "action": "call_rejected",
      "data": {
        "call_id": callId,
        "peer_user_id": peerUserId,
        "timestamp": DateTime.now().toIso8601String(),
      }
    };

    print('📞 Call: Sending call_rejected message to peer');
    await send(jsonEncode(message));
    print('📞 Call: Rejected call $callId successfully');

    _clearCall();
  }

  Future<void> endCall() async {
    if (_activeCall == null) return;

    _activeCall = _activeCall!.copyWith(
      state: CallState.ended,
      endTime: DateTime.now(),
      durationSeconds: _activeCall!.connectedTime != null
          ? DateTime.now().difference(_activeCall!.connectedTime!).inSeconds
          : 0,
    );

    await _saveCallLog(CallState.ended);
    _emitState();

    // Stop foreground service
    await CallForegroundService.instance.stopService();

    CallKitService.instance.endCall(_activeCall!.callId);

    final message = {
      "action": "call_ended",
      "data": {
        "call_id": _activeCall!.callId,
        "peer_user_id": _activeCall!.peerUserId,
        "duration": _activeCall!.durationSeconds,
        "timestamp": DateTime.now().toIso8601String(),
      }
    };

    await send(jsonEncode(message));
    print('📞 Call: Ended call ${_activeCall!.callId} (${_activeCall!.durationFormatted})');

    _clearCall();
  }

  void handleFcmIncomingCall(Map<String, dynamic> data) {
    final callId = (data['callId'] ?? data['call_id'] ?? '') as String;
    final peerUserId = (data['callerId'] ?? data['caller_id'] ?? '') as String;
    final peerPhone = (data['callerPhone'] ?? data['caller_phone'] ?? '') as String;
    final peerName = (data['callerName'] ?? data['caller_name'] ?? peerPhone) as String;
    final peerAvatar = (data['callerAvatar'] ?? data['caller_avatar'] ?? '') as String;
    final callType = (data['callType'] ?? data['call_type'] ?? 'voice') == 'video'
        ? CallType.video
        : CallType.voice;

    // Prevent duplicate FCM call handling
    if (callId.isEmpty || _activeCall?.callId == callId) {
      print('📞 Call: FCM duplicate call ignored - callId=$callId');
      return;
    }

    // Prevent race condition - if already in call, ignore FCM
    if (isInCall) {
      print('📞 Call: FCM ignored - already in a call');
      return;
    }

    _activeCall = CallSession(
      callId: callId,
      peerUserId: peerUserId,
      peerPhone: peerPhone,
      peerName: peerName,
      peerAvatar: peerAvatar,
      type: callType,
      state: CallState.ringing,
      direction: CallDirection.incoming,
    );
    _emitState();

    // Save incoming call log (isSelf = false for incoming)
    _saveCallLog(CallState.ringing);

    // Show CallKit incoming call UI from FCM
    CallKitService.instance.showIncomingCall(
      callId: callId,
      callerName: peerName,
      callerHandle: peerPhone.isNotEmpty ? peerPhone : peerUserId,
      callType: callType.name,
      extra: {
        'peerUserId': peerUserId,
        'peerName': peerName,
        'peerPhone': peerPhone,
        'peerAvatar': peerAvatar,
      },
    );

    print('📞 Call: FCM incoming call from $peerName');
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    final callId = data['call_id'] as String? ?? '';
    final peerUserId = data['sender_user_id'] as String? ?? '';
    final peerPhone = data['sender_phone'] as String? ?? '';
    final peerName = data['sender_name'] as String? ?? '';
    final peerAvatar = data['sender_avatar'] as String? ?? '';
    final callType = (data['call_type'] as String?) == 'video' ? CallType.video : CallType.voice;

    // Prevent duplicate call handling - check if we already have this call
    if (_activeCall?.callId == callId) {
      print('📞 Call: Duplicate incoming call ignored - already have callId=$callId');
      return;
    }

    // Prevent race condition - if already in call, send busy
    if (isInCall) {
      print('📞 Call: Already in a call, sending busy for new call');
      _sendBusy(callId, peerUserId);
      return;
    }

    _activeCall = CallSession(
      callId: callId,
      peerUserId: peerUserId,
      peerPhone: peerPhone,
      peerName: peerName,
      peerAvatar: peerAvatar,
      type: callType,
      state: CallState.ringing,
      direction: CallDirection.incoming,
    );

    _emitState();

    // Save incoming call log (isSelf = false for incoming)
    _saveCallLog(CallState.ringing);

    print('📞 Call: Incoming $callType call from $peerName');
  }

  void _handleCallAccepted(Map<String, dynamic> data) {
    print('📞 Call: Received call_accepted event: $data');
    print('📞 Call: Current active call: $_activeCall');
    
    if (_activeCall == null) {
      print('📞 Call: ERROR - No active call to accept');
      return;
    }

    final callId = data['call_id'] as String?;
    if (callId != null && callId != _activeCall!.callId) {
      print('📞 Call: Call ID mismatch - expected ${_activeCall!.callId}, got $callId');
      return;
    }

    _activeCall = _activeCall!.copyWith(
      state: CallState.connected,
      connectedTime: DateTime.now(),
    );

    _emitState();
    print('📞 Call: Peer accepted call ${_activeCall!.callId} - transitioning to connected state');
  }

  void _handleCallRejected(Map<String, dynamic> data) async {
    print('📞 Call: Received call_rejected event: $data');
    print('📞 Call: Current active call: $_activeCall');
    
    if (_activeCall == null) {
      print('📞 Call: ERROR - No active call to reject');
      return;
    }

    final callId = data['call_id'] as String?;
    if (callId != null && callId != _activeCall!.callId) {
      print('📞 Call: Call ID mismatch - expected ${_activeCall!.callId}, got $callId');
      return;
    }

    print('📞 Call: Updating state to rejected');
    _activeCall = _activeCall!.copyWith(
      state: CallState.rejected,
      endTime: DateTime.now(),
    );

    print('📞 Call: Saving call log and emitting state');
    await _saveCallLog(CallState.rejected);
    _emitState();
    _clearCall();
    print('📞 Call: Peer rejected call ${_activeCall!.callId} successfully');
  }

  void _handleCallBusy(Map<String, dynamic> data) async {
    print('📞 Call: Received call_busy event: $data');
    if (_activeCall == null) {
      print('📞 Call: No active call for busy response');
      return;
    }

    final callId = data['call_id'] as String?;
    if (callId != null && callId != _activeCall!.callId) {
      print('📞 Call: Call ID mismatch - expected ${_activeCall!.callId}, got $callId');
      return;
    }

    _activeCall = _activeCall!.copyWith(
      state: CallState.busy,
      endTime: DateTime.now(),
    );

    await _saveCallLog(CallState.busy);
    _emitState();
    _clearCall();
    print('📞 Call: Peer is busy - call ${_activeCall!.callId} ended');
  }

  void _handleCallEnded(Map<String, dynamic> data) async {
    if (_activeCall == null) return;

    final duration = data['duration'] as int? ?? 0;
    _activeCall = _activeCall!.copyWith(
      state: CallState.ended,
      endTime: DateTime.now(),
      durationSeconds: duration,
    );

    await _saveCallLog(CallState.ended);
    _emitState();
    _clearCall();
    print('📞 Call: Peer ended call (${_activeCall!.durationFormatted})');
  }

  void _handleCallMissed(Map<String, dynamic> data) async {
    if (_activeCall == null) return;

    _activeCall = _activeCall!.copyWith(
      state: CallState.missed,
      endTime: DateTime.now(),
    );

    await _saveCallLog(CallState.missed);
    _emitState();
    _clearCall();
    print('📞 Call: Missed call');
  }

  void _handleCallError(Map<String, dynamic> data) {
    final error = data['error'] ?? 'Unknown error';
    print('📞 Call: Error from server - $error');
    if (_activeCall != null) {
      _activeCall = _activeCall!.copyWith(
        state: CallState.ended,
        endTime: DateTime.now(),
      );
      _saveCallLog(CallState.ended);
      _emitState();
      _clearCall();
    }
  }

  void _sendBusy(String callId, String peerUserId) {
    final message = {
      "action": "call_busy",
      "data": {
        "call_id": callId,
        "peer_user_id": peerUserId,
        "timestamp": DateTime.now().toIso8601String(),
      }
    };
    unawaited(send(jsonEncode(message)));
  }

  /// Called from CallKit when restoring a session from background FCM data.
  void setActiveCall(CallSession session) {
    if (isInCall) return;
    _activeCall = session;
    _emitState();
    if (session.direction == CallDirection.incoming) {
      _saveCallLog(CallState.ringing);
    }
  }

  void _emitState() {
    if (_activeCall != null) {
      _callStateController.add(_activeCall!);
    }
  }

  void _clearCall() {
    Timer(const Duration(seconds: 3), () {
      if (_activeCall?.state == CallState.ended || 
          _activeCall?.state == CallState.rejected ||
          _activeCall?.state == CallState.missed ||
          _activeCall?.state == CallState.busy) {
        _activeCall = null;
        _sendViaChatChannel = null;
        _emitState();
      }
    });
  }

  void dispose() {
    _callStateController.close();
  }
}
