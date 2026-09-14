import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../core/constants.dart';

class ApiDebugService {
  /// 🏛️ Debug method to test the specific endpoint that's failing
  static Future<void> debugMyAppsEndpoint() async {
    if (kDebugMode) {
      debugPrint('🏛️ === DEBUGGING FAILING ENDPOINTS ===');
      
      // Test 1: Basic connectivity (working)
      try {
        final response = await http.get(
          Uri.parse('${StarlightConstants.apiBaseUrl}/system-identity/system-info'),
          headers: {'Content-Type': 'application/json'},
        );
        debugPrint('🏛️ Test 1 - System Info: Status ${response.statusCode}, Body: ${response.body}');
      } catch (e) {
        debugPrint('🏛️ Test 1 - System Info Failed: $e');
      }
      
      // Test 2: The failing my-apps endpoint with detailed debugging
      final testHardwareIds = ['mt6789', 'unknown_device', 'test_device', ''];
      
      for (final hardwareId in testHardwareIds) {
        try {
          final url = hardwareId.isEmpty 
              ? '${StarlightConstants.apiBaseUrl}/system-identity/my-apps'
              : '${StarlightConstants.apiBaseUrl}/system-identity/my-apps?hardware_id=$hardwareId';
          
          debugPrint('🏛️ Testing URL: $url');
          
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          );
          
          debugPrint('🏛️ My Apps (hardware_id: $hardwareId): Status ${response.statusCode}');
          debugPrint('🏛️ Response Headers: ${response.headers}');
          if (response.statusCode >= 400) {
            debugPrint('🏛️ Error Body: ${response.body}');
            debugPrint('🏛️ Error Body Length: ${response.body.length}');
          }
        } catch (e) {
          debugPrint('🏛️ My Apps Failed (hardware_id: $hardwareId): $e');
        }
      }
      
      // Test 3: Test register-app endpoint with minimal data
      try {
        final response = await http.post(
          Uri.parse('${StarlightConstants.apiBaseUrl}/system-identity/register-app'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'app_name': 'Debug Test App',
            'hardware_id': 'mt6789',
            'user_id': 1,
            'app_id': '',
          }),
        );
        
        debugPrint('🏛️ Register App Test: Status ${response.statusCode}');
        debugPrint('🏛️ Register App Response: ${response.body}');
        if (response.statusCode >= 400) {
          debugPrint('🏛️ Register App Error Details: ${response.body}');
        }
      } catch (e) {
        debugPrint('🏛️ Register App Failed: $e');
      }
      
      // Test 4: Test with empty body to see if endpoint exists
      try {
        final response = await http.post(
          Uri.parse('${StarlightConstants.apiBaseUrl}/system-identity/register-app'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: '{}',
        );
        
        debugPrint('🏛️ Register App Empty Body Test: Status ${response.statusCode}');
        debugPrint('🏛️ Register App Empty Response: ${response.body}');
      } catch (e) {
        debugPrint('🏛️ Register App Empty Body Failed: $e');
      }
      
      debugPrint('🏛️ === END DEBUGGING ===');
    }
  }
}
