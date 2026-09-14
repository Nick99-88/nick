import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:starlight_flutter/chat_system/services/fcm_call_saver.dart';
import 'package:starlight_flutter/services/socket/enhanced_socket_service.dart';
import 'package:starlight_flutter/chat_system/screens/unified_call_screen.dart';
import 'call_signaling_service.dart';

class CallKitService {
  static final CallKitService instance = CallKitService._init();
  CallKitService._init();

  bool _initialized = false;
  StreamSubscription<CallEvent?>? _eventSubscription;
  
  // Callback for navigating to call screen when accepting from CallKit
  void Function(CallSession)? _onCallAcceptedNavigate;
  
  // Set the navigation callback
  void setOnCallAcceptedNavigate(void Function(CallSession)? callback) {
    _onCallAcceptedNavigate = callback;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterCallkitIncoming.requestNotificationPermission({});
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }

      _eventSubscription = FlutterCallkitIncoming.onEvent.listen(_handleEvent);
    } catch (e) {
      print('🔔 CallKit: Init error - $e');
    }
  }

  void _handleEvent(CallEvent? event) {
    if (event == null) return;
    print('🔔 CallKit: Event ${event.eventName}');

    if (event is CallEventActionCallAccept) {
      _onAcceptCall(event.callKitParams);
    } else if (event is CallEventActionCallDecline) {
      _onDeclineCall(event.callKitParams);
    } else if (event is CallEventActionCallTimeout) {
      _onTimeoutCall(event.id);
    }
  }

  void _onAcceptCall(CallKitParams? params) async {
    print('🔔 CallKit: Accept call triggered');
    print('🔔 CallKit: Params - id: ${params?.id}, name: ${params?.nameCaller}, handle: ${params?.handle}');
    print('🔔 CallKit: Extra - ${params?.extra}');
    
    final callId = params?.id;
    if (callId == null) {
      print('🔔 CallKit: ERROR - callId is null');
      return;
    }
    
    var active = CallSignalingService.instance.activeCall;
    print('🔔 CallKit: Current active call - $active');

    // Restore session from CallKit params if app was killed and relaunched
    if (active == null && params?.extra != null) {
      print('🔔 CallKit: Restoring session from params');
      final extra = params!.extra!;
      final session = CallSession(
        callId: callId,
        peerUserId: extra['peerUserId'] as String? ?? '',
        peerPhone: extra['peerHandle'] as String? ?? (params.handle ?? ''),
        peerName: extra['peerName'] as String? ?? (params.nameCaller ?? ''),
        peerAvatar: extra['peerAvatar'] as String? ?? '',
        type: params.type == 1 ? CallType.video : CallType.voice,
        state: CallState.ringing,
        direction: CallDirection.incoming,
      );
      print('🔔 CallKit: Restored session - $session');
      CallSignalingService.instance.setActiveCall(session);
      active = session;
    }

    print('🔔 CallKit: Checking conditions - active: $active, callId match: ${active?.callId == callId}, state: ${active?.state}, direction: ${active?.direction}');
    
    if (active != null && active.callId == callId && active.state == CallState.ringing) {
      if (active.direction == CallDirection.incoming) {
        print('🔔 CallKit: Accepting incoming call $callId');
        
        // CRITICAL: Ensure WebSocket is connected BEFORE accepting call
        print('🔔 CallKit: Ensuring WebSocket connection before accept');
        if (!EnhancedSocketService.isConnected()) {
          print('🔔 CallKit: WebSocket not connected, connecting now...');
          try {
            await EnhancedSocketService.connect(source: 'CallKitAccept');
            print('🔔 CallKit: WebSocket connected successfully');
          } catch (e) {
            print('🔔 CallKit: ERROR - Failed to connect WebSocket: $e');
            // Still proceed with accept, but log the error
          }
        } else {
          print('🔔 CallKit: WebSocket already connected');
        }
        
        // Ensure send channel is set up for CallKit-initiated calls
        CallSignalingService.instance.setSendViaChatChannel((json) async {
          print('🔔 CallKit: Sending signaling via EnhancedSocketService');
          try {
            if (EnhancedSocketService.isConnected()) {
              EnhancedSocketService.sendRawMessage(json);
            } else {
              print('🔔 CallKit: ERROR - Socket not connected when trying to send');
            }
          } catch (e) {
            print('🔔 CallKit: Error sending - $e');
          }
        });
        
        print('🔔 CallKit: Calling acceptCall on CallSignalingService');
        CallSignalingService.instance.acceptCall();
        print('🔔 CallKit: acceptCall completed');
        
        // Navigate to call screen using the callback
        if (_onCallAcceptedNavigate != null) {
          print('🔔 CallKit: Navigating to call screen via callback');
          _onCallAcceptedNavigate!(active);
        } else {
          print('🔔 CallKit: WARNING - No navigation callback set, call screen may not appear');
        }
      } else {
        print('🔔 CallKit: ERROR - Call direction is not incoming: ${active.direction}');
      }
    } else {
      print('🔔 CallKit: ERROR - Cannot accept - active=$active, callId=$callId, state=${active?.state}');
    }
  }

  void _onDeclineCall(CallKitParams? params) async {
    print('🔔 CallKit: Decline call triggered');
    final callId = params?.id;
    if (callId == null) return;
    var active = CallSignalingService.instance.activeCall;

    // Restore from CallKit params if needed (app killed → FCM → CallKit decline)
    if (active == null && params?.extra != null) {
      print('🔔 CallKit: Restoring session from params for decline');
      final extra = params!.extra!;
      final session = CallSession(
        callId: callId,
        peerUserId: extra['peerUserId'] as String? ?? '',
        peerPhone: extra['peerHandle'] as String? ?? (params.handle ?? ''),
        peerName: extra['peerName'] as String? ?? (params.nameCaller ?? ''),
        peerAvatar: extra['peerAvatar'] as String? ?? '',
        type: params.type == 1 ? CallType.video : CallType.voice,
        state: CallState.ringing,
        direction: CallDirection.incoming,
      );
      CallSignalingService.instance.setActiveCall(session);
      active = session;
    }

    // CRITICAL: Ensure WebSocket is connected BEFORE declining call
    print('🔔 CallKit: Ensuring WebSocket connection before decline');
    if (!EnhancedSocketService.isConnected()) {
      print('🔔 CallKit: WebSocket not connected, connecting now...');
      try {
        await EnhancedSocketService.connect(source: 'CallKitDecline');
        print('🔔 CallKit: WebSocket connected successfully');
      } catch (e) {
        print('🔔 CallKit: ERROR - Failed to connect WebSocket: $e');
        // Still proceed with decline, but log the error
      }
    } else {
      print('🔔 CallKit: WebSocket already connected');
    }

    // Ensure send channel is set up
    CallSignalingService.instance.setSendViaChatChannel((json) async {
      print('🔔 CallKit: Sending decline signaling via EnhancedSocketService');
      try {
        if (EnhancedSocketService.isConnected()) {
          EnhancedSocketService.sendRawMessage(json);
        } else {
          print('🔔 CallKit: ERROR - Socket not connected when trying to send decline');
        }
      } catch (e) {
        print('🔔 CallKit: Error sending decline - $e');
      }
    });

    if (active != null && active.callId == callId) {
      if (active.state == CallState.ringing && active.direction == CallDirection.incoming) {
        print('🔔 CallKit: Rejecting incoming call $callId');
        CallSignalingService.instance.rejectCall();
      } else if (active.state == CallState.dialing && active.direction == CallDirection.outgoing) {
        print('🔔 CallKit: Ending outgoing call $callId');
        CallSignalingService.instance.endCall();
      }
    } else {
      print('🔔 CallKit: Cannot decline - active=$active, callId=$callId');
    }
  }

  void _onTimeoutCall(String callId) {
    final active = CallSignalingService.instance.activeCall;
    if (active != null && active.callId == callId) {
      if (active.direction == CallDirection.incoming) {
        CallSignalingService.instance.endCall();
      }
    } else {
      // No active session (e.g., app was killed and relaunched via CallKit)
      // Save as missed call directly
      FcmCallSaver.saveCallLog({
        'callId': callId,
        'callState': 'missed',
        'callDirection': 'incoming',
        'isSelf': false,
      });
    }
  }

  Future<void> showIncomingCall({
    required String callId,
    required String callerName,
    required String callerHandle,
    required String callType,
    Map<String, dynamic>? extra,
  }) async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
      await FlutterCallkitIncoming.showCallkitIncoming(
        CallKitParams(
          id: callId,
          nameCaller: callerName,
          appName: 'Starlight',
          avatar: '',
          handle: callerHandle,
          type: callType == 'video' ? 1 : 0,
          duration: 30000,
          extra: extra ?? {},
          android: AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            ringtonePath: 'iphone_tone',
            backgroundColor: '#FF075E54',
            backgroundUrl: '',
            actionColor: '#FF075E54',
            incomingCallNotificationChannelName: 'Starlight Calls',
            isFullScreen: true,
            textAccept: 'Accept',
            textDecline: 'Decline',
          ),
          ios: IOSParams(
            iconName: 'CallKitIcon',
            handleType: 'generic',
            supportsVideo: callType == 'video',
            maximumCallGroups: 1,
            maximumCallsPerCallGroup: 1,
            includesCallsInRecents: true,
            ringtonePath: 'iphone_tone.caf',
          ),
        ),
      );
    } catch (e) {
      print('🔔 CallKit: showIncomingCall error - $e');
    }
  }

  Future<void> showOutgoingCall({
    required String callId,
    required String calleeName,
    required String calleeHandle,
    required String callType,
  }) async {
    try {
      await FlutterCallkitIncoming.startCall(
        CallKitParams(
          id: callId,
          nameCaller: calleeName,
          appName: 'Starlight',
          avatar: '',
          handle: calleeHandle,
          type: callType == 'video' ? 1 : 0,
          extra: {'callId': callId},
          android: AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            ringtonePath: 'iphone_tone',
            backgroundColor: '#FF075E54',
            backgroundUrl: '',
            actionColor: '#FF075E54',
            incomingCallNotificationChannelName: 'Starlight Calls',
            isFullScreen: true,
          ),
          ios: IOSParams(
            iconName: 'CallKitIcon',
            handleType: 'generic',
            supportsVideo: callType == 'video',
            includesCallsInRecents: true,
          ),
        ),
      );
    } catch (e) {
      print('🔔 CallKit: showOutgoingCall error - $e');
    }
  }

  Future<void> reportCallConnected(String callId) async {
    try {
      await FlutterCallkitIncoming.setCallConnected(callId);
    } catch (e) {
      print('🔔 CallKit: setCallConnected error - $e');
    }
  }

  Future<void> endCall(String callId) async {
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      print('🔔 CallKit: endCall error - $e');
    }
  }

  Future<void> endAllCalls() async {
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      print('🔔 CallKit: endAllCalls error - $e');
    }
  }

  Future<void> hideIncomingCall(String callId) async {
    try {
      await FlutterCallkitIncoming.hideCallkitIncoming(
        CallKitParams(id: callId, nameCaller: '', appName: 'Starlight', handle: '', type: 0),
      );
    } catch (e) {
      print('🔔 CallKit: hideIncomingCall error - $e');
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
  }
}
