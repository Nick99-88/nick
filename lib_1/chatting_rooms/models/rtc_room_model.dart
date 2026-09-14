class RtcRoom {
  final String roomId;
  final String name;
  final String type; // 'one_speaker', 'one_video', 'all_speakers_one_video', 'all_speakers_all_videos'
  final String accessType; // 'open', 'password'
  final String controlType; // 'all_access', 'creator_only'
  final String visibility; // 'public', 'private'
  final String creatorId;
  final String creatorName;
  final String? institutionId;
  final String createdAt;
  final int activeParticipantsCount;
  final bool requiresPassword;

  RtcRoom({
    required this.roomId,
    required this.name,
    required this.type,
    required this.accessType,
    required this.controlType,
    required this.visibility,
    required this.creatorId,
    required this.creatorName,
    this.institutionId,
    required this.createdAt,
    required this.activeParticipantsCount,
    required this.requiresPassword,
  });

  factory RtcRoom.fromJson(Map<String, dynamic> json) {
    return RtcRoom(
      roomId: json['room_id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      accessType: json['access_type'] ?? '',
      controlType: json['control_type'] ?? '',
      visibility: json['visibility'] ?? '',
      creatorId: json['creator_id'] ?? '',
      creatorName: json['creator_name'] ?? '',
      institutionId: json['institution_id'],
      createdAt: json['created_at'] ?? '',
      activeParticipantsCount: json['active_participants_count'] ?? 0,
      requiresPassword: json['requires_password'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'name': name,
      'type': type,
      'access_type': accessType,
      'control_type': controlType,
      'visibility': visibility,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'institution_id': institutionId,
      'created_at': createdAt,
      'active_participants_count': activeParticipantsCount,
      'requires_password': requiresPassword,
    };
  }

  String get typeLabel {
    switch (type) {
      case 'one_speaker':
        return 'One Speaker (Broadcaster)';
      case 'one_video':
        return 'One Video (Teacher Video)';
      case 'all_speakers_one_video':
        return 'All Speakers, One Video';
      case 'all_speakers_all_videos':
        return 'All Speakers, All Videos';
      default:
        return 'Group Call';
    }
  }
}

class RtcParticipant {
  final String userId;
  final String name;
  final bool isCreator;
  bool camera;
  bool mic;

  RtcParticipant({
    required this.userId,
    required this.name,
    required this.isCreator,
    required this.camera,
    required this.mic,
  });

  factory RtcParticipant.fromJson(Map<String, dynamic> json) {
    return RtcParticipant(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      isCreator: json['is_creator'] ?? false,
      camera: json['camera'] ?? false,
      mic: json['mic'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'is_creator': isCreator,
      'camera': camera,
      'mic': mic,
    };
  }
}
