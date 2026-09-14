/// 🏛️ Institution Model
/// Represents an educational institution in the system
class InstitutionModel {
  final int id;
  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? description;
  final bool isActive;
  final int? staffCount;
  final int? studentCount;
  final int? teacherCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InstitutionModel({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.description,
    this.isActive = true,
    this.staffCount,
    this.studentCount,
    this.teacherCount,
    this.createdAt,
    this.updatedAt,
  });

  factory InstitutionModel.fromJson(Map<String, dynamic> json) {
    return InstitutionModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      website: json['website'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      staffCount: json['staff_count'],
      studentCount: json['student_count'],
      teacherCount: json['teacher_count'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'description': description,
      'is_active': isActive,
      'staff_count': staffCount,
      'student_count': studentCount,
      'teacher_count': teacherCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
