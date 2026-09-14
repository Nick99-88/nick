import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../../core/constants.dart';
import '../../../core/storage.dart';

class UserRole {
  final int id;
  final String institutionId;
  final String institutionName;
  final String role;
  final String? department;
  final String? gradeLevel;
  final String? employeeId;
  final bool isActive;
  final bool isPrimary;
  final String joinedAt;
  final String updatedAt;

  UserRole({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    required this.role,
    this.department,
    this.gradeLevel,
    this.employeeId,
    required this.isActive,
    required this.isPrimary,
    required this.joinedAt,
    required this.updatedAt,
  });

  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'],
      institutionId: json['institution_id'],
      institutionName: json['institution_name'],
      role: json['role'],
      department: json['department'],
      gradeLevel: json['grade_level'],
      employeeId: json['employee_id'],
      isActive: json['is_active'],
      isPrimary: json['is_primary'],
      joinedAt: json['joined_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class UserRolesService {
  static Future<List<UserRole>> getUserRoles() async {
    try {
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/user-roles/my-roles'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await StarlightStorage.getUserToken()}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UserRole.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user roles');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error loading user roles: $e');
      }
      return [];
    }
  }

  static Future<UserRole?> addRole({
    required String institutionId,
    required String role,
    String? department,
    String? gradeLevel,
    String? employeeId,
    bool isPrimary = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/user-roles/add-role'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await StarlightStorage.getUserToken()}',
        },
        body: jsonEncode({
          'institution_id': institutionId,
          'role': role,
          'department': department,
          'grade_level': gradeLevel,
          'employee_id': employeeId,
          'is_primary': isPrimary,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return UserRole.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to add role');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error adding user role: $e');
      }
      return null;
    }
  }

  static Future<bool> switchPrimaryRole(int userRoleId) async {
    try {
      final response = await http.put(
        Uri.parse('${StarlightConstants.apiBaseUrl}/user-roles/switch-primary/$userRoleId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await StarlightStorage.getUserToken()}',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Update local storage with new primary role
        await StarlightStorage.setInstitutionalToken(data['primary_institution_id']);
        await StarlightStorage.setUserRole(data['primary_role']);
        
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to switch primary role');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error switching primary role: $e');
      }
      return false;
    }
  }

  static Future<bool> removeRole(int userRoleId) async {
    try {
      final response = await http.delete(
        Uri.parse('${StarlightConstants.apiBaseUrl}/user-roles/remove-role/$userRoleId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await StarlightStorage.getUserToken()}',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to remove role');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error removing user role: $e');
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentContext() async {
    try {
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/user-roles/current-context'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await StarlightStorage.getUserToken()}',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get current context');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error getting current context: $e');
      }
      return null;
    }
  }

  static Future<UserRole?> getPrimaryRole() async {
    try {
      final roles = await getUserRoles();
      return roles.where((role) => role.isPrimary).firstOrNull;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error getting primary role: $e');
      }
      return null;
    }
  }

  static Future<List<UserRole>> getActiveRoles() async {
    try {
      final roles = await getUserRoles();
      return roles.where((role) => role.isActive).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error getting active roles: $e');
      }
      return [];
    }
  }

  static Future<List<UserRole>> getRolesByType(String roleType) async {
    try {
      final roles = await getUserRoles();
      return roles.where((role) => role.role == roleType).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error getting roles by type: $e');
      }
      return [];
    }
  }
}
