import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/constants.dart';
import '../../../core/storage.dart';
import '../models/server_models.dart';

class ServerProjectService {
  static const String _baseUrl = '${StarlightConstants.apiBaseUrl}/side/server';
  static const String _wsUrl = 'wss://api.institution.site/ws/side';

  // ── Project CRUD ──────────────────────────────────────

  static Future<List<ServerProject>> getMyProjects() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/projects'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['projects'] as List)
              .map((p) => ServerProject.fromJson(p))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<ServerProject?> createProject({
    required String name,
    required String description,
    required String framework,
    required ProjectVisibility visibility,
    List<String> tags = const [],
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/projects'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'framework': framework,
          'visibility': visibility.name,
          'tags': tags,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return ServerProject.fromJson(data['project']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> deleteProject(String projectId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/projects/$projectId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── File Operations ───────────────────────────────────

  static Future<List<ProjectFile>> getProjectFiles(String projectId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/projects/$projectId/files'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['files'] as List)
              .map((f) => ProjectFile.fromJson(f))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<String?> getFileContent(String projectId, String filePath) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/projects/$projectId/files/${Uri.encodeComponent(filePath)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data['content'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveFileContent(
    String projectId,
    String filePath,
    String content,
  ) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$_baseUrl/projects/$projectId/files/${Uri.encodeComponent(filePath)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'content': content}),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> createFile(
    String projectId,
    String filePath,
    String content,
  ) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/files'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'path': filePath,
          'content': content,
        }),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteFile(String projectId, String filePath) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/projects/$projectId/files/${Uri.encodeComponent(filePath)}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Push/Pull ─────────────────────────────────────────

  static Future<bool> pushProject({
    required String projectId,
    required Map<String, String> files,
    String? commitMessage,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/push'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'files': files,
          'commitMessage': commitMessage ?? 'Update project',
        }),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, String>?> pullProject(String projectId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/projects/$projectId/pull'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return Map<String, String>.from(data['files'] ?? {});
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── Container Management ──────────────────────────────

  static Future<bool> startContainer(
    String projectId,
    ContainerConfig config,
  ) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/container/start'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(config.toJson()),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stopContainer(String projectId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/container/stop'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> restartContainer(String projectId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/container/restart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Terminal WebSocket ────────────────────────────────

  static StreamController<TerminalLog>? _terminalController;
  static WebSocketChannel? _terminalChannel;

  static Stream<TerminalLog> connectTerminal(String projectId) {
    _terminalController?.close();
    _terminalController = StreamController<TerminalLog>.broadcast();

    _getAuthToken().then((token) {
      if (token == null) {
        _terminalController?.add(TerminalLog(
          stream: 'stderr',
          message: 'Authentication failed',
          timestamp: DateTime.now(),
        ));
        return;
      }

      final uri = Uri.parse('$_wsUrl/terminal/$projectId?token=$token');
      _terminalChannel = WebSocketChannel.connect(uri);

      _terminalChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data);
            _terminalController?.add(TerminalLog.fromJson(json));
          } catch (_) {}
        },
        onError: (error) {
          _terminalController?.add(TerminalLog(
            stream: 'stderr',
            message: 'Connection error: $error',
            timestamp: DateTime.now(),
          ));
        },
        onDone: () {
          _terminalController?.add(TerminalLog(
            stream: 'system',
            message: 'Terminal disconnected',
            timestamp: DateTime.now(),
          ));
        },
      );
    });

    return _terminalController!.stream;
  }

  static void sendTerminalCommand(String projectId, String command) {
    if (_terminalChannel != null) {
      _terminalChannel!.sink.add(jsonEncode({
        'type': 'command',
        'command': command,
      }));
    }
  }

  static void disconnectTerminal() {
    _terminalChannel?.sink.close();
    _terminalChannel = null;
    _terminalController?.close();
    _terminalController = null;
  }

  // ── Explore (Public Projects) ─────────────────────────

  static Future<List<ServerProject>> exploreProjects({
    String? framework,
    String? query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (framework != null) queryParams['framework'] = framework;
      if (query != null) queryParams['q'] = query;

      final uri = Uri.parse('$_baseUrl/explore')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return (data['projects'] as List)
              .map((p) => ServerProject.fromJson(p))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> forkProject(String projectId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$projectId/fork'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────

  static Future<String?> _getAuthToken() async {
    return await StarlightStorage.getUserToken();
  }

  static String getFrameworkLabel(String framework) {
    const labels = {
      'python': 'Python',
      'fastapi': 'FastAPI',
      'flask': 'Flask',
      'django': 'Django',
      'node': 'Node.js',
      'express': 'Express',
      'nextjs': 'Next.js',
      'flutter': 'Flutter',
      'java': 'Java',
      'spring': 'Spring Boot',
      'go': 'Go',
      'rust': 'Rust',
      'cpp': 'C++',
    };
    return labels[framework] ?? framework.toUpperCase();
  }
}
