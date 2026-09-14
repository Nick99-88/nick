import 'package:flutter/foundation.dart';
import '../../../core/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SimpleApiTest {
  /// Simple API endpoint testing for debugging
  static Future<void> testEndpoints() async {
    if (kDebugMode) {
      debugPrint('🔍 Simple API Test - Starting endpoint tests...');
      
      // Test basic connectivity
      await _testBasicConnectivity();
      
      // Test auth endpoint
      await _testAuthEndpoint();
      
      // Test explore endpoint
      await _testExploreEndpoint();
      
      debugPrint('🔍 Simple API Test - Completed');
    }
  }
  
  static Future<void> _testBasicConnectivity() async {
    try {
      debugPrint('🌐 Testing basic connectivity...');
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/'),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('🌐 Basic connectivity - Status: ${response.statusCode}');
      debugPrint('🌐 Basic connectivity - Response length: ${response.body.length}');
    } catch (e) {
      debugPrint('🌐 Basic connectivity - Error: $e');
    }
  }
  
  static Future<void> _testAuthEndpoint() async {
    try {
      debugPrint('🔐 Testing auth endpoint...');
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/auth/'),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('🔐 Auth endpoint - Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        debugPrint('🔐 Auth endpoint - Available');
      } else {
        debugPrint('🔐 Auth endpoint - Error: ${response.body}');
      }
    } catch (e) {
      debugPrint('🔐 Auth endpoint - Error: $e');
    }
  }
  
  static Future<void> _testExploreEndpoint() async {
    try {
      debugPrint('🔍 Testing explore endpoint...');
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/explore/debug/explore-test'),
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('🔍 Explore endpoint - Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🔍 Explore endpoint - Institutions found: ${data['count'] ?? 0}');
      } else {
        debugPrint('🔍 Explore endpoint - Error: ${response.body}');
      }
    } catch (e) {
      debugPrint('🔍 Explore endpoint - Error: $e');
    }
  }
  
  /// Quick health check
  static Future<bool> quickHealthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/explore/debug/explore-test'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏥 Health check failed: $e');
      }
      return false;
    }
  }
}
