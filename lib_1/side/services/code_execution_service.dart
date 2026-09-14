import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../models/execution_result.dart';

class CodeExecutionService {
  static const String _baseUrl = '${StarlightConstants.apiBaseUrl}/side';
  static const Duration _timeout = Duration(seconds: 30);

  static Future<ExecutionResult> execute({
    required String code,
    required String language,
    Map<String, String>? files,
    String input = '',
    String? entryFile,
  }) async {
    return _executeViaApi(
      code: code,
      language: language,
      files: files,
      input: input,
      entryFile: entryFile,
    );
  }

  static Future<ExecutionResult> _executeViaApi({
    required String code,
    required String language,
    Map<String, String>? files,
    String input = '',
    String? entryFile,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        stopwatch.stop();
        return ExecutionResult.error(
          error: 'Authentication required',
          executionTime: stopwatch.elapsed,
        );
      }

      final url = '$_baseUrl/execute';
      debugPrint('[CodeExecutionService] Sending POST $url — language: $language, code length: ${code.length}');

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'code': code,
              'language': language,
              if (files != null && files.isNotEmpty) 'files': files,
              if (input.isNotEmpty) 'input': input,
              if (entryFile != null && entryFile.isNotEmpty) 'entry_file': entryFile,
            }),
          )
          .timeout(_timeout);

      stopwatch.stop();
      debugPrint('[CodeExecutionService] Response — statusCode: ${response.statusCode}, body: ${response.body}, elapsed: ${stopwatch.elapsed.inMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return ExecutionResult.success(
            output: data['output'] ?? '',
            executionTime: stopwatch.elapsed,
          );
        } else {
          return ExecutionResult.error(
            error: data['error'] ?? 'Execution failed',
            executionTime: stopwatch.elapsed,
          );
        }
      } else {
        final data = jsonDecode(response.body);
        return ExecutionResult.error(
          error: data['message'] ?? 'Server error: ${response.statusCode}',
          executionTime: stopwatch.elapsed,
        );
      }
    } on TimeoutException {
      stopwatch.stop();
      return ExecutionResult.timeout();
    } on http.ClientException {
      stopwatch.stop();
      return ExecutionResult.error(
        error: 'Network error - check your connection',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return ExecutionResult.error(
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  // ── Challenge CRUD ──

  static Future<List<CodingChallenge>> getChallenges({
    String? language,
    String? difficulty,
    String? search,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return [];

      final q = <String, String>{};
      if (language != null && language != 'All') q['language'] = language.toLowerCase();
      if (difficulty != null && difficulty != 'All') q['difficulty'] = difficulty;
      if (search != null && search.isNotEmpty) q['search'] = search;

      final uri = Uri.parse('$_baseUrl/challenges').replace(queryParameters: q);
      final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['challenges'] as List).map((c) => CodingChallenge.fromJson(c)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[Challenges] getChallenges error: $e');
      return [];
    }
  }

  static Future<CodingChallenge?> getChallenge(String id) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final response = await http.get(
        Uri.parse('$_baseUrl/challenges/$id'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return CodingChallenge.fromJson(data['challenge']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<CodingChallenge?> createChallenge({
    required String title,
    required String description,
    required String difficulty,
    required String language,
    required String hint,
    required String starterCode,
    required List<String> testCases,
    required List<String> expectedOutputs,
    required String challengeType,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges'),
        headers: _headers(token),
        body: jsonEncode({
          'title': title,
          'description': description,
          'difficulty': difficulty,
          'language': language,
          'hint': hint,
          'starterCode': starterCode,
          'testCases': testCases,
          'expectedOutputs': expectedOutputs,
          'challengeType': challengeType,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return CodingChallenge.fromJson(data['challenge']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[Challenges] create error: $e');
      return null;
    }
  }

  // ── Save / Unsave ──

  static Future<bool> saveChallenge(String id) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/$id/save'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unsaveChallenge(String id) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;
      final response = await http.delete(
        Uri.parse('$_baseUrl/challenges/$id/save'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<CodingChallenge>> getSavedChallenges() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$_baseUrl/challenges/saved'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['challenges'] as List).map((c) => CodingChallenge.fromJson(c)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Replies ──

  static Future<ChallengeReply?> submitReply({
    required String challengeId,
    required String code,
    required String language,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/$challengeId/replies'),
        headers: _headers(token),
        body: jsonEncode({'code': code, 'language': language}),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return ChallengeReply.fromJson(data['reply']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[Challenges] reply error: $e');
      return null;
    }
  }

  static Future<ChallengeReply?> saveReplyOnly({
    required String challengeId,
    required String code,
    required String language,
    String? output,
    String? error,
    String status = 'submitted',
    int executionTimeMs = 0,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/$challengeId/replies/save'),
        headers: _headers(token),
        body: jsonEncode({
          'code': code,
          'language': language,
          if (output != null) 'output': output,
          if (error != null) 'error': error,
          'status': status,
          'executionTimeMs': executionTimeMs,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return ChallengeReply.fromJson(data['reply']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[Challenges] saveReplyOnly error: $e');
      return null;
    }
  }

  static Future<ChallengeReply?> updateReply({
    required String challengeId,
    required String replyId,
    required String code,
    required String language,
    String? output,
    String? error,
    String? status,
    int? executionTimeMs,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final response = await http.put(
        Uri.parse('$_baseUrl/challenges/$challengeId/replies/$replyId'),
        headers: _headers(token),
        body: jsonEncode({
          'code': code,
          'language': language,
          if (output != null) 'output': output,
          if (error != null) 'error': error,
          if (status != null) 'status': status,
          if (executionTimeMs != null) 'executionTimeMs': executionTimeMs,
        }),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return ChallengeReply.fromJson(data['reply']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[Challenges] updateReply error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> runReply({
    required String challengeId,
    required String replyId,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/$challengeId/replies/$replyId/run'),
        headers: _headers(token),
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('[Challenges] runReply error: $e');
      return null;
    }
  }

  static Future<List<ChallengeReply>> getReplies(String challengeId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$_baseUrl/challenges/$challengeId/replies'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['replies'] as List).map((r) => ChallengeReply.fromJson(r)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
}
