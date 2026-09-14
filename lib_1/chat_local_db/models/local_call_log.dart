class LocalCallLog {
  final int? id;
  final String peerUserId;
  final String peerName;
  final String peerAvatar;
  final String callType; // voice, video
  final String callDirection; // outgoing, incoming
  final String callState; // missed, rejected, busy, ended
  final int duration; // seconds
  final String callId;
  final bool isSelf; // true = outgoing (I called), false = incoming
  final String createdAt;
  final String updatedAt;

  LocalCallLog({
    this.id,
    required this.peerUserId,
    this.peerName = '',
    this.peerAvatar = '',
    required this.callType,
    required this.callDirection,
    required this.callState,
    this.duration = 0,
    this.callId = '',
    this.isSelf = false,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'peer_user_id': peerUserId,
      'peer_name': peerName,
      'peer_avatar': peerAvatar,
      'call_type': callType,
      'call_direction': callDirection,
      'call_state': callState,
      'duration': duration,
      'call_id': callId,
      'is_self': isSelf ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory LocalCallLog.fromMap(Map<String, dynamic> map) {
    return LocalCallLog(
      id: map['id'] as int?,
      peerUserId: (map['peer_user_id'] as String?) ?? '',
      peerName: (map['peer_name'] as String?) ?? '',
      peerAvatar: (map['peer_avatar'] as String?) ?? '',
      callType: (map['call_type'] as String?) ?? 'voice',
      callDirection: (map['call_direction'] as String?) ?? 'incoming',
      callState: (map['call_state'] as String?) ?? 'missed',
      duration: (map['duration'] as int?) ?? 0,
      callId: (map['call_id'] as String?) ?? '',
      isSelf: (map['is_self'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  LocalCallLog copyWith({
    int? id,
    String? peerUserId,
    String? peerName,
    String? peerAvatar,
    String? callType,
    String? callDirection,
    String? callState,
    int? duration,
    String? callId,
    bool? isSelf,
    String? createdAt,
    String? updatedAt,
  }) {
    return LocalCallLog(
      id: id ?? this.id,
      peerUserId: peerUserId ?? this.peerUserId,
      peerName: peerName ?? this.peerName,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      callType: callType ?? this.callType,
      callDirection: callDirection ?? this.callDirection,
      callState: callState ?? this.callState,
      duration: duration ?? this.duration,
      callId: callId ?? this.callId,
      isSelf: isSelf ?? this.isSelf,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayText {
    if (callDirection == 'outgoing') return 'Outgoing ${callType} call';
    if (callState == 'missed') return 'Missed ${callType} call';
    if (callState == 'rejected') return 'Rejected ${callType} call';
    return '${callDirection == 'incoming' ? 'Incoming' : 'Outgoing'} ${callType} call';
  }
}
