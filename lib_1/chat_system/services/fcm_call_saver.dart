import 'package:starlight_flutter/chat_local_db/chat_local_db.dart';

class FcmCallSaver {
  static Future<void> saveMissedCall(Map<String, dynamic> data) async {
    try {
      final callId = (data['callId'] ?? data['call_id'] ?? '') as String;
      final callerId = (data['callerId'] ?? data['caller_id'] ?? '') as String;
      final callerName = (data['callerName'] ?? data['caller_name'] ?? 'Someone') as String;
      final callerAvatar = (data['callerAvatar'] ?? data['caller_avatar'] ?? '') as String;
      final callType = (data['callType'] ?? data['call_type'] ?? 'voice') as String;

      if (callId.isEmpty || callerId.isEmpty) return;

      final log = LocalCallLog(
        peerUserId: callerId,
        peerName: callerName,
        peerAvatar: callerAvatar,
        callType: callType,
        callDirection: 'incoming',
        callState: 'missed',
        callId: callId,
        isSelf: false,
      );
      await CallLogRepository().insertOrUpdateCallLog(log);
    } catch (e) {
      print('📞 FcmCallSaver: Error - $e');
    }
  }

  static Future<void> saveCallLog(Map<String, dynamic> data) async {
    try {
      final callId = (data['callId'] ?? data['call_id'] ?? '') as String;
      final peerUserId = (data['peerUserId'] ?? data['peer_user_id'] ?? data['callerId'] ?? data['caller_id'] ?? '') as String;
      final peerName = (data['peerName'] ?? data['peer_name'] ?? data['callerName'] ?? data['caller_name'] ?? '') as String;
      final peerAvatar = (data['peerAvatar'] ?? data['peer_avatar'] ?? data['callerAvatar'] ?? data['caller_avatar'] ?? '') as String;
      final callType = (data['callType'] ?? data['call_type'] ?? 'voice') as String;
      final callDirection = (data['callDirection'] ?? data['call_direction'] ?? 'incoming') as String;
      final callState = (data['callState'] ?? data['call_state'] ?? 'missed') as String;
      final duration = int.tryParse((data['duration'] ?? data['duration'] ?? '0').toString()) ?? 0;
      final isSelf = (data['isSelf'] ?? data['is_self'] ?? false) as bool;

      if (callId.isEmpty || peerUserId.isEmpty) return;

      final log = LocalCallLog(
        peerUserId: peerUserId,
        peerName: peerName,
        peerAvatar: peerAvatar,
        callType: callType,
        callDirection: callDirection,
        callState: callState,
        duration: duration,
        callId: callId,
        isSelf: isSelf,
      );
      await CallLogRepository().insertOrUpdateCallLog(log);
    } catch (e) {
      print('📞 FcmCallSaver: Error saving call log - $e');
    }
  }
}
