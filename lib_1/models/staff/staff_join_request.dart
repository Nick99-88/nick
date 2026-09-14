/// 🏛️ Staff Join Request Model
/// Represents a request from a staff member to join an institution
class StaffJoinRequest {
  final String id;
  final int institutionId;
  final String? institutionName;
  final int staffId;
  final String? staffName;
  final String status; // 'pending', 'approved', 'rejected', 'cancelled'
  final String? message;
  final String? responseMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;

  StaffJoinRequest({
    required this.id,
    required this.institutionId,
    this.institutionName,
    required this.staffId,
    this.staffName,
    this.status = 'pending',
    this.message,
    this.responseMessage,
    this.createdAt,
    this.updatedAt,
    this.respondedAt,
  });

  factory StaffJoinRequest.fromJson(Map<String, dynamic> json) {
    return StaffJoinRequest(
      id: json['id']?.toString() ?? '',
      institutionId: json['institution_id'] ?? 0,
      institutionName: json['institution_name'],
      staffId: json['staff_id'] ?? 0,
      staffName: json['staff_name'],
      status: json['status'] ?? 'pending',
      message: json['message'],
      responseMessage: json['response_message'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institution_id': institutionId,
      'institution_name': institutionName,
      'staff_id': staffId,
      'staff_name': staffName,
      'status': status,
      'message': message,
      'response_message': responseMessage,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }

  /// Check if the request is pending
  bool get isPending => status == 'pending';

  /// Check if the request is approved
  bool get isApproved => status == 'approved';

  /// Check if the request is rejected
  bool get isRejected => status == 'rejected';

  /// Get status color for UI
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}
