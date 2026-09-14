import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../core/storage.dart';
import '../../../core/constants.dart';

class GeminiService {
  static const String _baseUrl = '${StarlightConstants.apiBaseUrl}/gemini';

  /// Compress image for better API performance
  static Future<Uint8List> _compressImage(Uint8List imageData) async {
    try {
      // Decode the image
      img.Image? image = img.decodeImage(imageData);
      if (image == null) {
        return imageData; // Return original if decoding fails
      }

      // Resize if too large (max 1920x1080 for good quality)
      if (image.width > 1920 || image.height > 1080) {
        image = img.copyResize(
          image,
          width: image.width > 1920 ? 1920 : null,
          height: image.height > 1080 ? 1080 : null,
          maintainAspect: true,
        );
      }

      // Compress with 85% quality
      Uint8List compressedData = Uint8List.fromList(img.encodeJpg(image, quality: 85));
      
      // If compressed is smaller, use it; otherwise use original
      return compressedData.length < imageData.length ? compressedData : imageData;
    } catch (e) {
      print('Image compression failed: $e');
      return imageData; // Return original if compression fails
    }
  }

  /// Scan paper image and extract questions using secure server relay
  static Future<Map<String, dynamic>> scanPaper(Uint8List imageData) async {
    try {
      // Compress image for better performance
      Uint8List compressedData = await _compressImage(imageData);
      print('Original size: ${imageData.length}, Compressed size: ${compressedData.length}');
      
      // Convert image to base64
      String base64Image = base64Encode(compressedData);
      
      // Get authentication token
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        print('Authentication failed: No token found');
        return {
          'error': 'Authentication failed',
          'paperInfo': {'title': 'Unknown', 'totalQuestions': 0},
          'questions': []
        };
      }
      
      print('Sending request to server relay...');
      
      // Prepare request payload for server
      final payload = {
        'imageData': base64Image,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/scan-paper'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 90)); // 90 second timeout for server processing

      print('Server relay response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Server relay response received successfully');
        
        if (responseData['status'] == 'success') {
          print('Paper scanned successfully via server relay');
          return Map<String, dynamic>.from(responseData['data'] as Map);
        } else {
          print('Server relay returned error: ${responseData['message']}');
          return {
            'error': responseData['message'] ?? 'Server relay error',
            'paperInfo': {'title': 'Unknown', 'totalQuestions': 0},
            'questions': []
          };
        }
      } else {
        print('Server relay error: ${response.statusCode} - ${response.body}');
        return {
          'error': 'Server relay error: ${response.statusCode}',
          'rawResponse': response.body,
          'paperInfo': {'title': 'Unknown', 'totalQuestions': 0},
          'questions': []
        };
      }
    } on http.ClientException catch (e) {
      print('Network error: $e');
      return {
        'error': 'Network error: $e',
        'paperInfo': {'title': 'Unknown', 'totalQuestions': 0},
        'questions': []
      };
    } catch (e) {
      print('Unexpected error: $e');
      return {
        'error': 'Unexpected error: $e',
        'paperInfo': {'title': 'Unknown', 'totalQuestions': 0},
        'questions': []
      };
    }
  }

  /// Extract JSON from text response (handles cases where Gemini adds extra text)
  static String _extractJsonFromText(String text) {
    // Look for JSON object in the text
    int startIndex = text.indexOf('{');
    int endIndex = text.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return text.substring(startIndex, endIndex + 1);
    }
    
    throw Exception('No JSON found in response');
  }

  /// Validate and clean the response from Gemini
  static Map<String, dynamic> _validateAndCleanResponse(Map<String, dynamic> data) {
    Map<String, dynamic> validatedData = {
      'paperInfo': {},
      'questions': [],
    };

    // Validate paper info
    if (data['paperInfo'] != null) {
      final info = Map<String, dynamic>.from(data['paperInfo'] as Map);
      validatedData['paperInfo'] = {
        'title': info['title']?.toString() ?? 'Unknown Paper',
        'totalQuestions': info['totalQuestions']?.toInt() ?? 0,
        'maxMarks': info['maxMarks']?.toInt() ?? 0,
        'duration': info['duration']?.toString() ?? '',
        'instructions': info['instructions']?.toString() ?? '',
        'subject': info['subject']?.toString() ?? '',
        'grade': info['grade']?.toString() ?? '',
      };
    }

    // Validate questions
    if (data['questions'] != null && data['questions'] is List) {
      List<Map<String, dynamic>> validatedQuestions = [];
      
      for (var i = 0; i < data['questions'].length; i++) {
        var question = Map<String, dynamic>.from(data['questions'][i] as Map);
        Map<String, dynamic> validatedQuestion = {};

        // Ensure required fields
        validatedQuestion['id'] = question['id']?.toString() ?? 'q_${i + 1}';
        validatedQuestion['questionNumber'] = question['questionNumber']?.toInt() ?? (i + 1);
        validatedQuestion['type'] = question['type']?.toString() ?? 'Long';
        validatedQuestion['questionText'] = question['questionText']?.toString() ?? '';
        validatedQuestion['marks'] = question['marks']?.toInt() ?? 5;
        validatedQuestion['difficulty'] = question['difficulty']?.toString() ?? 'Medium';
        validatedQuestion['topic'] = question['topic']?.toString() ?? 'General';

        // Ensure options field exists for MCQ
        final qType = validatedQuestion['type'].toString().toLowerCase();
        if (qType == 'mcq') {
          validatedQuestion['options'] = question['options'] is List 
              ? (question['options'] as List).map((e) => e.toString()).toList()
              : [];
        } else {
          validatedQuestion['options'] = [];
        }

        // Ensure subQuestions field exists
        validatedQuestion['subQuestions'] = question['subQuestions'] is List 
            ? (question['subQuestions'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];

        validatedQuestions.add(validatedQuestion);
      }
      
      validatedData['questions'] = validatedQuestions;
      validatedData['paperInfo']['totalQuestions'] = validatedQuestions.length;
    }

    return validatedData;
  }

  /// Generate exam paper PDF via AI with formatting options
  static Future<Map<String, dynamic>> generatePaper({
    required List<Map<String, dynamic>> questions,
    required Map<String, dynamic> options,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        return {'error': 'Authentication failed'};
      }

      final payload = {
        'questions': questions,
        'options': options,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/generate-paper'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('application/pdf')) {
          final paperStructure = response.headers['x-paper-structure'];
          return {
            'status': 'success',
            'pdf_bytes': response.bodyBytes,
            'paper_structure': paperStructure != null ? jsonDecode(paperStructure) : null,
          };
        }
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        return {
          'error': errorBody['message'] ?? 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'error': 'Generation failed: $e'};
    }
  }

  /// Validate and clean scanned questions (legacy method for compatibility)
  static Map<String, dynamic> validateScannedData(Map<String, dynamic> data) {
    return _validateAndCleanResponse(data);
  }
}
