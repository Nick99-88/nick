class GroupMember {
  final int? id;
  final String groupId;
  final String userId;
  final String phoneNumber;
  final String displayName;
  final String role;
  final String joinedAt;

  const GroupMember({
    this.id,
    required this.groupId,
    required this.userId,
    this.phoneNumber = '',
    this.displayName = '',
    this.role = 'member',
    this.joinedAt = '',
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] as int?,
      groupId: map['group_id'] as String,
      userId: map['user_id'] as String,
      phoneNumber: map['phone_number'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      joinedAt: map['joined_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'group_id': groupId,
      'user_id': userId,
      'phone_number': phoneNumber,
      'display_name': displayName,
      'role': role,
      'joined_at': joinedAt,
    };
  }

  GroupMember copyWith({
    int? id,
    String? groupId,
    String? userId,
    String? phoneNumber,
    String? displayName,
    String? role,
    String? joinedAt,
  }) {
    return GroupMember(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isCreator => role == 'creator';

  String get displayInitials {
    if (displayName.isNotEmpty) {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName[0].toUpperCase();
    }
    return '?';
  }

  @override
  String toString() => 'GroupMember(userId: $userId, displayName: $displayName, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember && runtimeType == other.runtimeType && userId == other.userId;

  @override
  int get hashCode => userId.hashCode;
}
