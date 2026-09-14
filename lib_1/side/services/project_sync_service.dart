import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../models/virtual_project.dart';

class ServerProjectInfo {
  final String id;
  final String name;
  final String framework;
  ServerProjectInfo({required this.id, required this.name, required this.framework});
}

class ProjectSyncService {
  static const String _baseUrl = '${StarlightConstants.apiBaseUrl}/side/server';

  static Future<String?> createServerProject(VirtualProject project) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final response = await http.post(
        Uri.parse('$_baseUrl/projects'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': project.name,
          'framework': project.language,
          'description': '',
          'visibility': 'private',
          'files': project.files.map((f) => {
            'path': f.name,
            'content': f.content,
          }).toList(),
        }),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      return data['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> pushFiles(String serverProjectId, VirtualProject project) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;
      final files = <String, String>{};
      for (final f in project.files) {
        files[f.name] = f.content;
      }
      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$serverProjectId/push'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'files': files,
          'commit_message': 'Push from SIDE IDE',
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<ServerProjectInfo>> listServerProjects() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return [];
      final response = await http.get(
        Uri.parse('$_baseUrl/projects'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as List;
      return data.map((json) => ServerProjectInfo(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        framework: json['framework'] ?? 'python',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<VirtualProject?> pullProject(String serverProjectId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;
      final projResp = await http.get(
        Uri.parse('$_baseUrl/projects/$serverProjectId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (projResp.statusCode != 200) return null;
      final projData = jsonDecode(projResp.body);
      final filesResp = await http.get(
        Uri.parse('$_baseUrl/projects/$serverProjectId/files'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (filesResp.statusCode != 200) return null;
      final filesData = jsonDecode(filesResp.body) as List;
      final now = DateTime.now().millisecondsSinceEpoch;
      final files = filesData.map((f) => VirtualFile(
        id: '${now}_${f['path']}',
        name: f['path'] ?? '',
        content: f['content'] ?? '',
      )).toList();
      final folders = <String>{};
      for (final f in files) {
        final folder = f.folder;
        if (folder != '/') folders.add(folder);
      }
      return VirtualProject(
        id: projData['id'] ?? serverProjectId,
        name: projData['name'] ?? 'Untitled',
        language: projData['framework'] ?? 'python',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        files: files,
        folders: folders.toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deleteServerProject(String serverProjectId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;
      final response = await http.delete(
        Uri.parse('$_baseUrl/projects/$serverProjectId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Save a project's environment file on the backend, attached to the
  /// server project so hosting created "from GitHub" includes it.
  static Future<bool> pushEnv(
      String serverProjectId, String envName, String envContent) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return false;
      final response = await http.post(
        Uri.parse('$_baseUrl/projects/$serverProjectId/env'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'project_id': serverProjectId,
          'env_name': envName,
          'env_content': envContent,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
