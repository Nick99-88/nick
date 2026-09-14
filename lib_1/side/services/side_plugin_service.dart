import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../models/side_plugin.dart';

class SidePluginService {
  static const String _baseUrl = '${StarlightConstants.apiBaseUrl}/side/plugins';

  static Future<Map<String, String>> _headers() async {
    final token = await StarlightStorage.getUserToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Future<List<SidePlugin>> getPlugins({String? language}) async {
    try {
      final headers = await _headers();
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: language != null ? {'language': language} : null,
      );
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => SidePlugin.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('[SidePluginService] getPlugins error: $e');
    }
    return [];
  }

  static Future<SidePlugin?> getPlugin(String pluginId) async {
    try {
      final headers = await _headers();
      final response = await http.get(
        Uri.parse('$_baseUrl/$pluginId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return SidePlugin.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('[SidePluginService] getPlugin error: $e');
    }
    return null;
  }

  static Future<bool> installPlugin(String pluginId) async {
    try {
      final headers = await _headers();
      final response = await http.post(
        Uri.parse('$_baseUrl/$pluginId/install'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SidePluginService] installPlugin error: $e');
      return false;
    }
  }

  static Future<bool> uninstallPlugin(String pluginId) async {
    try {
      final headers = await _headers();
      final response = await http.delete(
        Uri.parse('$_baseUrl/$pluginId/install'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SidePluginService] uninstallPlugin error: $e');
      return false;
    }
  }

  static Future<List<SidePlugin>> getInstalledPlugins() async {
    try {
      final headers = await _headers();
      final response = await http.get(
        Uri.parse('$_baseUrl/installed/list'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) {
          final pluginData = e['plugin'];
          if (pluginData != null) {
            return SidePlugin.fromJson(pluginData);
          }
          return SidePlugin.fromJson(e);
        }).toList();
      }
    } catch (e) {
      debugPrint('[SidePluginService] getInstalledPlugins error: $e');
    }
    return [];
  }

  static Future<bool> addPluginToProject(String pluginId, String projectId) async {
    try {
      final headers = await _headers();
      final response = await http.post(
        Uri.parse('$_baseUrl/$pluginId/project/$projectId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SidePluginService] addPluginToProject error: $e');
      return false;
    }
  }

  static Future<bool> removePluginFromProject(String pluginId, String projectId) async {
    try {
      final headers = await _headers();
      final response = await http.delete(
        Uri.parse('$_baseUrl/$pluginId/project/$projectId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[SidePluginService] removePluginFromProject error: $e');
      return false;
    }
  }

  static Future<List<SidePlugin>> getProjectPlugins(String projectId) async {
    try {
      final headers = await _headers();
      final response = await http.get(
        Uri.parse('$_baseUrl/project/$projectId/list'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) {
          final pluginData = e['plugin'];
          if (pluginData != null) {
            return SidePlugin.fromJson(pluginData);
          }
          return SidePlugin.fromJson(e);
        }).toList();
      }
    } catch (e) {
      debugPrint('[SidePluginService] getProjectPlugins error: $e');
    }
    return [];
  }
}
