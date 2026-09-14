import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/service_connection.dart';
import '../services/service_auth_service.dart';
import '../services/github_client.dart';
import '../widgets/sheet_scaffold.dart';
import 'github_repo_files_screen.dart';
import 'method_chooser_sheet.dart';

/// 🏛️ Manage GitHub repositories: list, create, edit and delete, all from
/// the app. Open a repo in the SIDE IDE to push/pull real files.
class GithubReposScreen extends StatefulWidget {
  final GitHubRepo? deleteTarget;
  const GithubReposScreen({super.key, this.deleteTarget});

  @override
  State<GithubReposScreen> createState() => _GithubReposScreenState();
}

class _GithubReposScreenState extends State<GithubReposScreen> {
  final _auth = ServiceAuthService.instance;
  List<GitHubRepo> _repos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (mounted && widget.deleteTarget != null) {
        _delete(widget.deleteTarget!);
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await _auth.githubToken();
      if (token != null) {
        _repos = await GitHubClient(token).listRepos();
      } else {
        // OAuth connected: the backend lists repos with its stored token.
        _repos = await _auth.fetchGithubReposViaBackend();
      }
      _error = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _repos = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final desc = TextEditingController();
    var priv = true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('New repository',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, color: const Color(0xFF212121))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: svcInput('Repository name'),
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: desc,
                decoration: svcInput('Description (optional)'),
                style: GoogleFonts.poppins(fontSize: 13),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Private',
                    style: GoogleFonts.poppins(fontSize: 13)),
                value: priv,
                activeColor: const Color(0xFF2E7D32),
                onChanged: (v) => set(() => priv = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Text('Create', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    try {
      final token = await _auth.githubToken();
      if (token != null) {
        await GitHubClient(token).createRepo(
          name: name.text.trim(),
          description: desc.text.trim(),
          private: priv,
        );
      } else {
        await _auth.createGithubRepoViaBackend(
          name: name.text.trim(),
          description: desc.text.trim(),
          private: priv,
        );
      }
      _load();
    } catch (e) {
      _showErr(e);
    }
  }

  Future<void> _delete(GitHubRepo repo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFC62828), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Delete repository?',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF212121))),
            ),
          ],
        ),
        content: Text(
          'You are about to permanently delete '
          '${repo.fullName}. This action cannot be undone and all code, '
          'issues and PRs will be lost.',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: const Color(0xFF8A8F98))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final token = await _auth.githubToken();
      if (token != null) {
        await GitHubClient(token).deleteRepo(repo.fullName);
      } else {
        await _auth.deleteGithubRepoViaBackend(repo.fullName);
      }
      _load();
    } catch (e) {
      _showErr(e);
    }
  }

  void _showErr(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', ''),
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: const Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
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
        title: Text('GitHub Repositories',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: const Color(0xFF212121))),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF1A237E)),
            onPressed: _create,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1A237E)),
            onPressed: _load,
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 40, color: Color(0xFF8A8F98)),
              const SizedBox(height: 12),
              Text(_error!,
                  style: GoogleFonts.poppins(fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _connect(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                ),
                child: Text('Connect GitHub',
                    style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      );
    }
    if (_repos.isEmpty) {
      return Center(
        child: Text('No repositories yet.',
            style: GoogleFonts.poppins(color: const Color(0xFF8A8F98))),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF1A237E),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _repos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final r = _repos[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFECEEF2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.code_rounded,
                        color: Color(0xFF1A237E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GithubRepoFilesScreen(repo: r),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.fullName,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF212121))),
                          if (r.description != null &&
                              r.description!.isNotEmpty)
                            Text(r.description!,
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF8A8F98))),
                          Text('branch: ${r.defaultBranch}',
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF8A8F98))),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFC62828)),
                    onPressed: () => _delete(r),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _connect() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MethodChooserSheet(provider: ServiceProvider.github),
    );
    _load();
  }
}
