import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';

class SetupService {
  final String _baseUrl = StarlightConstants.apiBaseUrl;

  /// 🏛️ Main setup function called from main.dart
  /// Fetches all required data and stores in preferences
  Future<Map<String, dynamic>> performInitialSetup() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      // 🏛️ Backend-only approach - no local database migration
      debugPrint('🏛️ Setup Service: Backend-only - no local database migration needed');

      // Parallel fetch all setup data
      final results = await Future.wait([
        _checkUserInstitutionStatus(token),
        _checkPhoneVerificationStatus(token),
        _fetchDashboardData(token),
      ]);

      final institutionStatus = results[0];
      final phoneStatus = results[1];
      final dashboardData = results[2];

      // Store in preferences
      await _storeSetupData(institutionStatus, phoneStatus, dashboardData);

      return {
        'success': true,
        'has_institution': institutionStatus['has_institution'] ?? false,
        'phone_verified': phoneStatus['is_verified'] ?? false,
        'dashboard_data': dashboardData,
      };
    } catch (e) {
      debugPrint('🏛️ Setup Service Error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🏛️ Check if user has institution setup completed
  Future<Map<String, dynamic>> _checkUserInstitutionStatus(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/setup/check-institution'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? "Failed to check institution status");
  }

  /// 🏛️ Check phone verification status
  Future<Map<String, dynamic>> _checkPhoneVerificationStatus(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/setup/phone-status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? "Failed to check phone verification");
  }

  /// 🏛️ Fetch dashboard data (student, teacher, staff counts)
  Future<Map<String, dynamic>> _fetchDashboardData(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/dashboard/stats'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? "Failed to fetch dashboard data");
  }

  /// 🏛️ Store setup data in preferences
  Future<void> _storeSetupData(
    Map<String, dynamic> institutionStatus,
    Map<String, dynamic> phoneStatus,
    Map<String, dynamic> dashboardData,
  ) async {
    // Store institution status
    await StarlightStorage.setHasInstitution(institutionStatus['has_institution'] ?? false);
    
    // Store phone verification status
    await StarlightStorage.setPhoneVerified(phoneStatus['is_verified'] ?? false);
    if (phoneStatus['phone_number'] != null) {
      await StarlightStorage.setUserPhoneNumber(phoneStatus['phone_number']);
    }

    // Store dashboard data
    await StarlightStorage.setDashboardData(jsonEncode(dashboardData));
  }

  /// 🏛️ Update institution has_institution status when professional bio is completed
  Future<void> updateInstitutionStatus() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/setup/complete-institution'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await StarlightStorage.setHasInstitution(true);
        debugPrint('🏛️ Institution status updated successfully');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['detail'] ?? "Failed to update institution status");
      }
    } catch (e) {
      debugPrint('🏛️ Update Institution Status Error: $e');
      rethrow;
    }
  }

  /// 🏛️ Update phone verification status
  Future<void> updatePhoneVerification(String phoneNumber) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/setup/verify-phone'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'is_verified': true,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('🏛️ Phone verification updated successfully');
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['detail'] ?? "Failed to update phone verification");
      }
    } catch (e) {
      debugPrint('🏛️ Update Phone Verification Error: $e');
      rethrow;
    }
  }
}
