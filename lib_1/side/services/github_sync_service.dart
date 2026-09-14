import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../core/storage.dart';
import '../../services_management/models/service_connection.dart';
import '../../services_management/services/service_auth_service.dart';
import '../../services_management/services/github_client.dart';
import '../models/virtual_project.dart';

/// 🏛️ Separate, additive GitHub sync for the SIDE IDE. Keeps the existing
/// backend push/pull untouched and instead reads/writes REAL local files
/// that are mirrored to a GitHub repository via the connected account.
class GithubSyncService {
  GithubSyncService._();
  static final GithubSyncService instance = GithubSyncService._();

  /// Resolves a usable GitHub access token. PAT connections store the token
  /// locally; OAuth connections broker the token on the backend, so a PAT is
  /// required for direct client-side push/pull.
  Future<String?> resolveToken() async {
    final pat = await ServiceAuthService.instance.readSecret(
      ServiceProvider.github,
      AuthMethod.pat,
    );
    if (pat != null && pat.isNotEmpty) return pat;
    return null;
  }

  Future<bool> isConnected() async => (await resolveToken()) != null;

  Future<List<GitHubRepo>> listRepos() async {
    final token = await resolveToken();
    if (token == null) return [];
    try {
      return await GitHubClient(token).listRepos();
    } catch (_) {
      return [];
    }
  }

  Future<Directory> _localDir(String fullName) async {
    final base = await getApplicationDocumentsDirectory();
    final safe = fullName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '__');
    final dir = Directory('${base.path}/side_github/$safe');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Pull a repo's files into real local files and return a VirtualProject
  /// the IDE can load.
  Future<VirtualProject> pull(String fullName, String branch) async {
    final token = await resolveToken();
    if (token == null) throw Exception('No GitHub connection (add a PAT).');
    final client = GitHubClient(token);
    final dir = await _localDir(fullName);
    final paths = await client.listFilePaths(fullName, branch);

    final now = DateTime.now().millisecondsSinceEpoch;
    final files = <VirtualFile>[];
    for (final p in paths) {
      final gf = await client.getFile(fullName, branch, p);
      // Persist as a REAL file on disk.
      final diskPath = '${dir.path}/$p';
      final diskFile = File(diskPath);
      await diskFile.parent.create(recursive: true);
      await diskFile.writeAsString(gf.content);
      files.add(VirtualFile(
        id: '${now}_$p',
        name: p,
        content: gf.content,
      ));
    }
    final folders = <String>{};
    for (final f in files) {
      if (f.folder != '/') folders.add(f.folder);
    }
    return VirtualProject(
      id: 'gh_${now}_$fullName',
      name: fullName.split('/').last,
      language: 'python',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      files: files,
      folders: folders.toList(),
    );
  }

  /// Push the current VirtualProject's files to the repo. Files are first
  /// written to real local disk, then uploaded to GitHub.
  Future<void> push(String fullName, String branch, VirtualProject project) async {
    final token = await resolveToken();
    if (token == null) throw Exception('No GitHub connection (add a PAT).');
    final client = GitHubClient(token);
    final dir = await _localDir(fullName);
    for (final f in project.files) {
      final rel = f.name.startsWith('/') ? f.name.substring(1) : f.name;
      final diskFile = File('${dir.path}/$rel');
      await diskFile.parent.create(recursive: true);
      await diskFile.writeAsString(f.content);

      String? sha;
      try {
        sha = (await client.getFile(fullName, branch, rel)).sha;
      } catch (_) {
        sha = null; // new file
      }
      await client.putFile(
        fullName,
        branch,
        rel,
        f.content,
        sha: sha,
        message: 'Update ${rel} via Starlight SIDE IDE',
      );
    }
  }

  String localPathFor(String fullName) {
    // Best-effort path for display; the directory is created on first sync.
    return 'side_github/${fullName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '__')}';
  }
}
