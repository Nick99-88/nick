import 'dart:convert';
import 'package:http/http.dart' as http;

/// 🏛️ Minimal GitHub REST client used to push/pull REAL files to/from repos.
/// All calls are authenticated with a Personal Access Token (PAT) or the
/// access token brokered through the OAuth flow.
class GitHubClient {
  GitHubClient(this.token);

  final String token;

  static const _api = 'https://api.github.com';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${token.trim()}',
        'Accept': 'application/vnd.github+json',
      };

  Future<Map<String, dynamic>> _json(Uri uri) async {
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('GitHub ${uri.path} -> ${res.statusCode}: ${res.body}');
  }

  /// List repositories the token can access.
  Future<List<GitHubRepo>> listRepos() async {
    final res = await http.get(Uri.parse('$_api/user/repos?per_page=100'),
        headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Could not list repos (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List;
    return list
        .map((e) => GitHubRepo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Recursively collect file paths (blobs) for a repo at [ref]..
  Future<List<String>> listFilePaths(String fullName, String ref) async =>
      _collectPaths(fullName, ref, '');

  Future<List<String>> _collectPaths(
      String fullName, String ref, String path) async {
    final uri = Uri.parse('$_api/repos/$fullName/contents/$path')
        .replace(queryParameters: {'ref': ref});
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) {
      throw Exception('Could not read contents (${res.statusCode})');
    }
    final items = jsonDecode(res.body) as List;
    final files = <String>[];
    for (final it in items) {
      final item = it as Map<String, dynamic>;
      final p = item['path'] as String;
      if (item['type'] == 'dir') {
        files.addAll(await _collectPaths(fullName, ref, p));
      } else if (item['type'] == 'file') {
        files.add(p);
      }
    }
    return files;
  }

  /// Fetch decoded text content and the blob sha for a single file.
  Future<GitHubFile> getFile(String fullName, String ref, String path) async {
    final uri = Uri.parse('$_api/repos/$fullName/contents/$path')
        .replace(queryParameters: {'ref': ref});
    final data = await _json(uri);
    final content = _decode(data['content'] as String?, data['encoding']);
    return GitHubFile(
      path: data['path'] as String,
      content: content,
      sha: data['sha'] as String?,
    );
  }

  String _decode(String? content, String? encoding) {
    if (content == null) return '';
    if (encoding == 'base64') {
      return utf8.decode(base64Decode(content.replaceAll('\n', '')));
    }
    return content;
  }

  /// Create or update a file in the repo.
  Future<void> putFile(
    String fullName,
    String ref,
    String path,
    String content, {
    String? sha,
    String message = 'Update via Starlight',
  }) async {
    final body = {
      'message': message,
      'content': base64Encode(utf8.encode(content)),
      'branch': ref,
      if (sha != null) 'sha': sha,
    };
    final res = await http.put(
      Uri.parse('$_api/repos/$fullName/contents/$path'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Upload failed (${res.statusCode}): ${res.body}');
    }
  }

  /// Create a new repository under the authenticated account.
  Future<GitHubRepo> createRepo({
    required String name,
    String? description,
    bool private = true,
  }) async {
    final res = await http.post(
      Uri.parse('$_api/user/repos'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'description': description ?? '',
        'private': private,
        'auto_init': true,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Create repo failed (${res.statusCode}): ${res.body}');
    }
    return GitHubRepo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Delete a repository by full name (owner/repo).
  Future<void> deleteRepo(String fullName) async {
    final res = await http.delete(
      Uri.parse('$_api/repos/$fullName'),
      headers: _headers,
    );
    if (res.statusCode != 204 && res.statusCode != 200) {
      throw Exception('Delete repo failed (${res.statusCode}): ${res.body}');
    }
  }
}

class GitHubRepo {
  final String fullName;
  final String defaultBranch;
  final String? description;

  GitHubRepo({
    required this.fullName,
    required this.defaultBranch,
    this.description,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) => GitHubRepo(
        fullName: json['full_name'] as String,
        defaultBranch: (json['default_branch'] as String?) ?? 'main',
        description: json['description'] as String?,
      );
}

class GitHubFile {
  final String path;
  final String content;
  final String? sha;

  GitHubFile({required this.path, required this.content, this.sha});
}
