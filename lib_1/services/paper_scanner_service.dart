import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/storage.dart';
import '../../../core/constants.dart';
import '../models/scanned_question_models.dart';

class PaperScannerService {
  static const String _baseUrl = '${StarlightConstants.apiBaseUrl}/paper-scanner';

  /// Save selected questions to the question bank
  static Future<Map<String, dynamic>> saveQuestions({
    required String paperId,
    required PaperInfo paperInfo,
    required List<ScannedQuestion> selectedQuestions,
  }) async {
    try {
      print('PaperScannerService: Starting save questions process...');
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        print('PaperScannerService: Authentication failed - no token');
        throw Exception('Authentication failed');
      }
      print('PaperScannerService: Token obtained successfully');

      // Get user and institution IDs from storage
      final userId = await StarlightStorage.getUserId();
      if (userId == null) {
        print('PaperScannerService: User ID not found');
        throw Exception('User ID not found');
      }
      
      final payload = {
        'paperId': paperId,
        'paperInfo': paperInfo.toJson(),
        'selectedQuestions': selectedQuestions.map((q) => q.toJson()).toList(),
        'institutionId': userId, // Using userId as institutionId for now, should be updated to get actual institution ID
        'userId': userId,
      };
      
      print('PaperScannerService: Using userId: $userId');
      
      print('PaperScannerService: Payload prepared with ${selectedQuestions.length} questions');
      print('PaperScannerService: Sending request to $_baseUrl/save-questions');

      final response = await http.post(
        Uri.parse('$_baseUrl/save-questions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      print('PaperScannerService: Response received - Status: ${response.statusCode}');
      print('PaperScannerService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('PaperScannerService: Questions saved successfully');
        return responseData;
      } else {
        print('PaperScannerService: Server error - ${response.statusCode} - ${response.body}');
        throw Exception('Failed to save questions: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('PaperScannerService: Exception occurred - $e');
      throw Exception('Error saving questions: $e');
    }
  }

  /// Get questions from question bank with optional filters
  static Future<Map<String, dynamic>> getQuestionBank({
    String? subject,
    String? grade,
    String? difficulty,
    String? questionType,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('Authentication failed');
      }

      Uri uri = Uri.parse('$_baseUrl/question-bank');
      final queryParams = <String, String>{};
      
      if (subject != null) queryParams['subject'] = subject;
      if (grade != null) queryParams['grade'] = grade;
      if (difficulty != null) queryParams['difficulty'] = difficulty;
      if (questionType != null) queryParams['question_type'] = questionType;
      
      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get questions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting questions: $e');
    }
  }

  /// Delete a question from question bank
  static Future<Map<String, dynamic>> deleteQuestion(int questionId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('Authentication failed');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/question/$questionId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to delete question: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting question: $e');
    }
  }

  /// Get question bank statistics
  static Future<Map<String, dynamic>> getQuestionStats() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('Authentication failed');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/stats'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting stats: $e');
    }
  }
}
