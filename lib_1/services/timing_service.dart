import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/storage.dart';

class TimingService {
  // Institutional Timing
  static Future<Map<String, dynamic>> getInstitutionalTiming() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/institution/timing'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load institutional timing');
      }
    } catch (e) {
      throw Exception('Error loading institutional timing: $e');
    }
  }

  static Future<bool> saveInstitutionalTiming({
    String? openingTime,
    String? closingTime,
    List<String>? workingDays,
    List<Map<String, dynamic>>? breakTimes,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/institution/timing'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'opening_time': openingTime,
          'closing_time': closingTime,
          'working_days': workingDays,
          'break_times': breakTimes,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error saving institutional timing: $e');
    }
  }

  // Staff & Teachers
  static Future<Map<String, dynamic>> getStaffAndTeachers() async {
    try {
      final token = await StarlightStorage.getUserToken();
      debugPrint('🏛️ TimingService: GET ${StarlightConstants.apiBaseUrl}/dashboard/staff-teachers');
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/dashboard/staff-teachers'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('🏛️ TimingService: Response status: ${response.statusCode}');
      debugPrint('🏛️ TimingService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load staff and teachers');
      }
    } catch (e) {
      throw Exception('Error loading staff and teachers: $e');
    }
  }

  static Future<bool> saveSchedule({
    required String personnelId,
    required String personnelType,
    required Map<String, dynamic> schedule,
    bool isWholeDayAdmin = false,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final url = '${StarlightConstants.apiBaseUrl}/dashboard/save-schedule';
      final body = jsonEncode({
        'personnel_id': personnelId,
        'personnel_type': personnelType,
        'schedule': schedule,
        'is_whole_day_admin': isWholeDayAdmin,
      });
      
      debugPrint('🏛️ TimingService: POST $url');
      debugPrint('🏛️ TimingService: Request body: $body');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      debugPrint('🏛️ TimingService: Save response status: ${response.statusCode}');
      debugPrint('🏛️ TimingService: Save response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error saving schedule: $e');
    }
  }

  // Utility methods
  static String formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static TimeOfDay parseTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    final parts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  // Data transformation helpers
  static List<Map<String, dynamic>> convertStaffList(List<dynamic> dynamicList) {
    return dynamicList.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Map<String, dynamic> convertSchedule(dynamic scheduleData) {
    return scheduleData != null 
        ? Map<String, dynamic>.from(scheduleData) 
        : {};
  }
}
