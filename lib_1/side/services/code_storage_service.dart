import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/code_project.dart';

class CodeStorageService {
  static const String _projectsKey = 'side_projects_v1';

  static Future<void> saveProject(CodeProject project) async {
    final prefs = await SharedPreferences.getInstance();
    final projects = await getAllProjects();
    final index = projects.indexWhere((p) => p.id == project.id);

    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.insert(0, project);
    }

    final jsonList = projects.map((p) => p.toJson()).toList();
    await prefs.setString(_projectsKey, jsonEncode(jsonList));
  }

  static Future<List<CodeProject>> getAllProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_projectsKey);
    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => CodeProject.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<CodeProject?> getProject(String id) async {
    final projects = await getAllProjects();
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final projects = await getAllProjects();
    projects.removeWhere((p) => p.id == id);

    final jsonList = projects.map((p) => p.toJson()).toList();
    await prefs.setString(_projectsKey, jsonEncode(jsonList));
  }

  static Future<List<CodeProject>> searchProjects(String query) async {
    final projects = await getAllProjects();
    final lowerQuery = query.toLowerCase();
    return projects.where((p) =>
        p.name.toLowerCase().contains(lowerQuery) ||
        p.language.toLowerCase().contains(lowerQuery)).toList();
  }

  static Future<void> syncToCloud(CodeProject project) async {
    // Phase 2: Firebase/Firestore sync
    // For now, mark as synced locally
    await saveProject(project.copyWith(isCloudSynced: true));
  }
}
