import 'package:starlight_flutter/core/starlight_http.dart';
import 'package:starlight_flutter/core/token_manager.dart';
import 'package:starlight_flutter/core/constants.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class DashboardApiException implements Exception {
  final int statusCode;
  final String message;
  DashboardApiException(this.statusCode, this.message);
  @override
  String toString() => 'DashboardApiException($statusCode): $message';
}

class DashboardService {
  final String baseUrl = "${StarlightConstants.apiBaseUrl}/dashboard";
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/scanner";

  // ==========================================
  // 🎓 STUDENT MANAGEMENT (7 ROUTES)
  // ==========================================

  // 1. Admit Single Student

  Future<Map<String, dynamic>> admitStudent(Map<String, dynamic> payload, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.post(
      Uri.parse("$baseUrl/admit-student"),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Admission failed");
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> processAIScan(File imageFile) async {
    var request = http.MultipartRequest(
        'POST', Uri.parse('$_baseUrl/admission/scan-register'));

    request.files
        .add(await http.MultipartFile.fromPath('file', imageFile.path));

    final token = await TokenManager.instance.getValidToken();
    request.headers.addAll({'Authorization': 'Bearer $token'});

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw DashboardApiException(response.statusCode, "Failed to scan: ${response.body}");
    }
  }

  // 2. Bulk Admit (AI Scan Result)
  Future<void> bulkAdmitStudents(List<Map<String, dynamic>> students) async {
    final response = await StarlightHttp.post(
      Uri.parse("$baseUrl/bulk-admit-students"),
      body: jsonEncode(students),
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Bulk registration failed");
  }

  // 3. Get All My Students
  Future<dynamic> getMyStudents() async {
    final response = await StarlightHttp.get(Uri.parse("$baseUrl/my_students"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw DashboardApiException(response.statusCode, "Could not fetch students");
  }

  // 4. Get Students by Section
  Future<List<dynamic>> getStudentsBySection(String sectionName) async {
    final response = await StarlightHttp.get(Uri.parse("$baseUrl/students/${Uri.encodeComponent(sectionName)}"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // 5. Update Student Record
  Future<void> editStudent(String id, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.put(
      Uri.parse("$baseUrl/edit_student/$id"),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Update failed");
  }

  // 6. Delete Student
  Future<void> deleteStudent(String id, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.delete(Uri.parse("$baseUrl/delete_student/$id"), headers: headers);
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Deletion failed");
  }

  // 6b. Regenerate Student access key
  Future<String> regenerateStudentKey(String id, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.post(
      Uri.parse("$baseUrl/regenerate-student-key/$id"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Key regeneration failed");
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access_key'] as String;
  }

  // 7. Rename Entire Section
  Future<void> renameSection(String oldName, String newName, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.patch(
      Uri.parse("$baseUrl/rename_section?old_name=${Uri.encodeQueryComponent(oldName)}&new_name=${Uri.encodeQueryComponent(newName)}"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Section rename failed");
  }

  // 7b. Delete Entire Section
  Future<void> deleteSection(String sectionName, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.delete(
      Uri.parse("$baseUrl/delete_section/${Uri.encodeComponent(sectionName)}"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Section deletion failed");
  }

  // ==========================================
  // 🍎 TEACHER MANAGEMENT (6 ROUTES)
  // ==========================================

  // 8. Hire Teacher
  Future<void> hireTeacher(Map<String, dynamic> payload, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.post(
      Uri.parse("$baseUrl/hire-teacher"),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Hiring failed");
  }

  // 9. Get Teacher List
  Future<Map<String, dynamic>> getTeacherList() async {
    final response = await StarlightHttp.get(Uri.parse("$baseUrl/teacher-list"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw DashboardApiException(response.statusCode,"Could not fetch teachers");
  }

  // 10. Get Teachers by Subject
  Future<List<dynamic>> getTeachersBySubject(String subjectName) async {
    final response = await StarlightHttp.get(Uri.parse("$baseUrl/teachers/$subjectName"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // 11. Update Teacher
  Future<void> updateTeacher(String id, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.patch(
      Uri.parse("$baseUrl/teacher/$id"),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Teacher update failed");
  }

  // 12. Delete Teacher
  Future<void> deleteTeacher(String id, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.delete(Uri.parse("$baseUrl/teacher/$id"), headers: headers);
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Deletion failed");
  }

  // Regenerate Teacher access key
  Future<String> regenerateTeacherKey(String id, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.post(
      Uri.parse("$baseUrl/regenerate-teacher-key/$id"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Key regeneration failed");
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access_key'] as String;
  }

  // ==========================================
  // 🧑‍🏫 SECTION TEACHER ASSIGNMENTS (3 ROUTES)
  // ==========================================

  // Assign Teacher to Section (with subject)
  Future<void> assignTeacherToSection(String teacherId, String sectionName, String subjectName) async {
    final response = await StarlightHttp.post(
      Uri.parse("$baseUrl/assign-teacher"),
      body: jsonEncode({
        "teacher_id": teacherId,
        "section_name": sectionName,
        "subject_name": subjectName,
      }),
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Assignment failed");
  }

  // Get Teachers Assigned to a Section
  Future<List<dynamic>> getSectionTeachers(String sectionName) async {
    final response = await StarlightHttp.get(
      Uri.parse("$baseUrl/section-teachers/${Uri.encodeComponent(sectionName)}"),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Get Sections a Teacher is Assigned To
  Future<List<dynamic>> getTeacherSections(String teacherId) async {
    final response = await StarlightHttp.get(Uri.parse("$baseUrl/teacher-sections/$teacherId"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Remove Teacher Assignment from Section
  Future<void> removeTeacherFromSection(String sectionName, String teacherId, String subjectName) async {
    final response = await StarlightHttp.delete(
      Uri.parse("$baseUrl/section-teachers/${Uri.encodeComponent(sectionName)}/$teacherId?subject=${Uri.encodeComponent(subjectName)}"),
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Unassignment failed");
  }

  // ==========================================
  // 🛠️ STAFF MANAGEMENT (6 ROUTES)
  // ==========================================

  // 13. Hire Staff
  Future<void> hireStaff(Map<String, dynamic> payload, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.post(
      Uri.parse("$baseUrl/Hire_staff"),
      body: jsonEncode(payload),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Staff hiring failed");
  }

  // 14. Get Staff List
  Future<Map<String, dynamic>> getStaffList() async {
    final response = await StarlightHttp.get(Uri.parse("$baseUrl/Staff_list"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw DashboardApiException(response.statusCode,"Could not fetch staff");
  }

  // 15. Get Staff by Role
  Future<List<dynamic>> getStaffByRole(String roleName) async {
    final response = await StarlightHttp.get(Uri.parse("$baseUrl/staff/$roleName"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // 16. Update Staff
  Future<void> updateStaff(String id, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.patch(
      Uri.parse("$baseUrl/update_staff/$id"),
      body: jsonEncode(data),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Staff update failed");
  }

  // 17. Delete Staff
  Future<void> deleteStaff(String id, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.delete(Uri.parse("$baseUrl/delete_staff/$id"), headers: headers);
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Deletion failed");
  }

  // Regenerate Staff access key
  Future<String> regenerateStaffKey(String id, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.post(
      Uri.parse("$baseUrl/regenerate-staff-key/$id"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode, "Key regeneration failed");
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['access_key'] as String;
  }

  // ==========================================
  // 🏢 INSTITUTION UTILITIES (6 ROUTES)
  // ==========================================

  // 18. Get Unique Sections (For Dropdowns)
  Future<List<String>> getSections() async {
    try {
      final response = await StarlightHttp.get(Uri.parse("$baseUrl/sections"));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((s) => s.toString()).toList();
      } else {
        throw DashboardApiException(response.statusCode,"Server returned ${response.statusCode}");
      }
    } catch (e) {
      throw DashboardApiException(0, "Network connectivity issue: $e");
    }
  }

  // 19. Get Subjects
  Future<List<String>> getSubjects() async {
    try {
      final response = await StarlightHttp.get(Uri.parse("$baseUrl/subjects"));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((s) => s.toString()).toList();
      } else {
        throw DashboardApiException(response.statusCode,"Server returned ${response.statusCode}");
      }
    } catch (e) {
      throw DashboardApiException(0, "Network connectivity issue: $e");
    }
  }

  // 20. Rename Subject
  Future<void> renameSubject(String oldName, String newName, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.patch(
      Uri.parse("$baseUrl/rename_subject?old_name=$oldName&new_name=$newName"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Subject rename failed");
  }

  // 20b. Delete Subject
  Future<void> deleteSubject(String subjectName, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.delete(
      Uri.parse("$baseUrl/delete_subject/$subjectName"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Subject deletion failed");
  }

  // 20c. Delete Subjects (Bulk)
  Future<void> deleteSubjects(List<String> subjectNames, {Map<String, String>? headers}) async {
    for (final name in subjectNames) {
      await deleteSubject(name, headers: headers);
    }
  }

  // 21. Get Roles
  Future<List<String>> getRoles() async {
    try {
      final response = await StarlightHttp.get(Uri.parse("$baseUrl/roles"));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((r) => r.toString()).toList();
      } else {
        throw DashboardApiException(response.statusCode,"Server returned ${response.statusCode}");
      }
    } catch (e) {
      throw DashboardApiException(0, "Network connectivity issue: $e");
    }
  }

  // 22. Rename Role
  Future<void> renameRole(String oldName, String newName, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.patch(
      Uri.parse("$baseUrl/rename_role?old_name=$oldName&new_name=$newName"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Role rename failed");
  }

  // 22b. Delete Role
  Future<void> deleteRole(String roleName, {Map<String, String>? headers}) async {
    final response = await StarlightHttp.delete(
      Uri.parse("$baseUrl/delete_role/$roleName"),
      headers: headers,
    );
    if (response.statusCode != 200) throw DashboardApiException(response.statusCode,"Role deletion failed");
  }

  // 23. Verify Ownership & Get AI Credits
  Future<Map<String, dynamic>> verifyOwnership() async {
    final response = await StarlightHttp.get(Uri.parse("$baseUrl/check-ownership"));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw DashboardApiException(response.statusCode,"Ownership verification failed");
  }
}
