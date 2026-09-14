import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/service_connection.dart';
import '../services/service_auth_service.dart';
import '../services/github_client.dart';
import 'github_repos_screen.dart';

/// 🏛️ File-tree view for a single GitHub repository.
class GithubRepoFilesScreen extends StatefulWidget {
  final GitHubRepo repo;
  const GithubRepoFilesScreen({super.key, required this.repo});

  @override
  State<GithubRepoFilesScreen> createState() => _GithubRepoFilesScreenState();
}

class _GithubRepoFilesScreenState extends State<GithubRepoFilesScreen> {
  final _auth = ServiceAuthService.instance;
  late String _branch;
  _Node? _root;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _branch = widget.repo.defaultBranch;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final parts = widget.repo.fullName.split('/');
      final tree = await _auth.fetchRepoTreeViaBackend(
          parts[0], parts[1], _branch);
      _root = _buildTree(tree);
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _Node _buildTree(List<dynamic> entries) {
    final root = _Node('', '', true);
    for (final e in entries) {
      final path = e['path'] as String;
      final isDir = (e['type'] ?? 'blob') == 'tree';
      final segments = path.split('/');
      var node = root;
      for (var i = 0; i < segments.length; i++) {
        final seg = segments[i];
        final last = i == segments.length - 1;
        final child = node.children
            .where((c) => c.name == seg)
            .firstOrNull;
        if (child != null) {
          node = child;
        } else {
          final n = _Node(
            seg,
            segments.sublist(0, i + 1).join('/'),
            last ? isDir : true,
            size: last ? (e['size'] as int?) : null,
          );
          node.children.add(n);
          node = n;
        }
      }
    }
    _sort(root);
    return root;
  }

  void _sort(_Node n) {
    n.children.sort((a, b) {
      if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    for (final c in n.children) _sort(c);
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repository settings',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF212121))),
            const SizedBox(height: 14),
            _settingRow(Icons.folder_rounded, widget.repo.fullName),
            _settingRow(Icons.account_tree_rounded, 'Branch: $_branch'),
            _settingRow(
                Icons.lock_outline_rounded,
                widget.repo.description ?? 'No description'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GithubReposScreen(deleteTarget: widget.repo),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete repository'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1A237E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFF212121))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF212121)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.repo.fullName,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF212121))),
            Text('branch: $_branch',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: const Color(0xFF8A8F98))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF1A237E)),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A237E)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              style: GoogleFonts.poppins(fontSize: 13),
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_root == null || _root!.children.isEmpty) {
      return Center(
        child: Text('No files found.',
            style: GoogleFonts.poppins(color: const Color(0xFF8A8F98))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _root!.children.length,
      itemBuilder: (ctx, i) => _TreeTile(node: _root!.children[i], depth: 0),
    );
  }
}

class _Node {
  final String name;
  final String path;
  final bool isDir;
  final int? size;
  final List<_Node> children;
  _Node(this.name, this.path, this.isDir, {this.size, this.children = const []});
}

class _TreeTile extends StatefulWidget {
  final _Node node;
  final int depth;
  const _TreeTile({required this.node, required this.depth});

  @override
  State<_TreeTile> createState() => _TreeTileState();
}

class _TreeTileState extends State<_TreeTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final indent = EdgeInsets.only(left: 12.0 * widget.depth);
    if (n.isDir) {
      return Column(
        children: [
          ListTile(
            contentPadding: indent.copyWith(right: 16),
            leading: Icon(
              _expanded ? Icons.folder_open_rounded : Icons.folder_rounded,
              color: const Color(0xFF1A237E),
            ),
            title: Text(n.name,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF212121))),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xFF8A8F98),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            ...n.children
                .map((c) => _TreeTile(node: c, depth: widget.depth + 1)),
        ],
      );
    }
    return ListTile(
      contentPadding: indent.copyWith(right: 16),
      leading: const Icon(Icons.insert_drive_file_outlined,
          color: Color(0xFF8A8F98), size: 20),
      title: Text(n.name,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF212121))),
      subtitle: n.size != null
          ? Text('${(n.size! / 1024).toStringAsFixed(1)} KB',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF8A8F98)))
          : null,
    );
  }
}
