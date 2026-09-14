import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:code_text_field/code_text_field.dart';
import 'package:highlight/highlight_core.dart' as hl;
import 'package:highlight/languages/python.dart' as py;
import 'package:highlight/languages/javascript.dart' as js_lang;
import 'package:highlight/languages/cpp.dart' as cpp_lang;
import 'package:highlight/languages/java.dart' as java_lang;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/virtual_project.dart';
import '../models/language_model.dart';
import '../models/side_plugin.dart';
import '../services/virtual_storage_service.dart';
import '../services/project_sync_service.dart';
import '../services/github_sync_service.dart';
import '../services/side_plugin_service.dart';
import '../widgets/code_editor.dart';
import '../widgets/run_button.dart';
import '../widgets/file_tree_widget.dart';
import '../widgets/interactive_terminal.dart';
import '../widgets/interactive_execution_terminal.dart';
import '../../widgets/intro_widgets/coding_ide_intro.dart';
import '../../widgets/intro_widgets/intro_check.dart';
import '../../core/app_routes.dart';
import '../../services_management/services/github_client.dart';
import 'challenges_screen.dart';



class SideIdeScreen extends StatefulWidget {
  const SideIdeScreen({super.key});

  @override
  State<SideIdeScreen> createState() => _SideIdeScreenState();
}

class _SideIdeScreenState extends State<SideIdeScreen> {
  late CodeController _codeController;

  VirtualProject? _currentProject;
  VirtualFile? _selectedFile;
  String _selectedLanguage = 'python';
  int _terminalRunKey = 0;
  List<VirtualProject> _projects = [];
  bool _showSidebar = true;
  bool _showTerminal = true;
  int _sidebarTab = 0;
  List<VirtualFile> _openFiles = [];
  String? _activeTabFileId;
  final Map<String, String> _serverProjectIds = {};

  int _terminalTab = 0;
  List<ServerProjectInfo> _serverProjects = [];
  ServerProjectInfo? _selectedServerProject;

  static final Map<String, hl.Mode> _highlightModes = {
    'python': py.python,
    'javascript': js_lang.javascript,
    'cpp': cpp_lang.cpp,
    'c': cpp_lang.cpp,
    'java': java_lang.java,
  };

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: '',
      language: _highlightModes[_selectedLanguage],
      stringMap: _buildStringMap(),
    );
    _loadProjects();
    _loadServerProjects();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Map<String, TextStyle> _buildStringMap() {
    final map = <String, TextStyle>{};
    for (final kw in {
      'def', 'class', 'if', 'elif', 'else', 'for', 'while', 'try',
      'except', 'finally', 'with', 'as', 'import', 'from', 'return',
      'yield', 'lambda', 'and', 'or', 'not', 'in', 'is', 'True',
      'False', 'None', 'pass', 'break', 'continue', 'raise', 'global',
      'nonlocal', 'assert', 'del', 'async', 'await',
      'function', 'const', 'let', 'var', 'new', 'this', 'super',
      'switch', 'case', 'default', 'do', 'typeof', 'instanceof',
      'export', 'extends', 'implements',
      'interface', 'type', 'enum', 'namespace', 'module', 'declare',
      'abstract', 'public', 'private', 'protected', 'static', 'readonly',
      'void', 'null', 'undefined', 'true', 'false',
      'int', 'float', 'double', 'char', 'long', 'short', 'unsigned',
      'signed', 'struct', 'union', 'typedef', 'sizeof',
      'extern', 'register', 'volatile', 'auto', 'inline',
      'bool', 'wchar_t',
    }) {
      map[kw] = const TextStyle(color: Color(0xFFFF79C6), fontWeight: FontWeight.bold);
    }
    for (final bi in {
      'print', 'len', 'range', 'input', 'str', 'int', 'float', 'list',
      'dict', 'tuple', 'set', 'bool', 'type', 'isinstance', 'enumerate',
      'zip', 'map', 'filter', 'sorted', 'reversed', 'abs', 'max', 'min',
      'sum', 'round', 'open', 'format', 'super', 'property',
      'console', 'log', 'document', 'window', 'JSON', 'Math', 'Date',
      'Array', 'Object', 'Promise', 'fetch', 'setTimeout', 'setInterval',
      'parseInt', 'parseFloat', 'isNaN',
      'cout', 'cin', 'cerr', 'endl', 'string', 'vector',
      'queue', 'stack', 'pair', 'std', 'using', 'namespace',
      'printf', 'scanf', 'malloc', 'free', 'NULL', 'EOF',
      'System', 'out', 'println', 'String', 'Integer', 'Double', 'Float',
      'Boolean', 'ArrayList', 'HashMap', 'Scanner', 'Exception',
      'Thread', 'StringBuilder', 'File', 'Override',
    }) {
      map[bi] = const TextStyle(color: Color(0xFF8BE9FD));
    }
    return map;
  }

  Future<void> _loadProjects() async {
    final projects = await VirtualStorageService.getAllProjects();
    if (!mounted) return;
    setState(() => _projects = projects);
    if (_currentProject == null && projects.isNotEmpty) {
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _onProjectSelected(projects.first);
    }
    if (_currentProject != null && _projects.isEmpty) {
      _currentProject = null;
      _selectedFile = null;
      _codeController.text = '';
    }
  }

  Future<void> _loadServerProjects() async {
    final projects = await ProjectSyncService.listServerProjects();
    if (!mounted) return;
    setState(() => _serverProjects = projects);
  }

  void _selectServerProject(ServerProjectInfo? proj) {
    setState(() => _selectedServerProject = proj);
  }

  void _onProjectSelected(VirtualProject project) {
    setState(() {
      _currentProject = project;
      _sidebarTab = 1;
      _selectedLanguage = project.language;
      _selectedFile = null;
      _openFiles = [];
      _activeTabFileId = null;
      _terminalRunKey++;
    });
    if (project.files.isNotEmpty) _onFileSelected(project.files.first);
  }

  String? _serverIdForProject(String localId) => _serverProjectIds[localId];
  void _setServerId(String localId, String serverId) => _serverProjectIds[localId] = serverId;

  String _languageForFile(VirtualFile file) {
    final ext = file.extension.toLowerCase();
    if (ext == '.py') return 'python';
    if (['.js', '.jsx', '.ts', '.tsx'].contains(ext)) return 'javascript';
    if (['.cpp', '.cc', '.cxx', '.hpp'].contains(ext)) return 'cpp';
    if (['.c', '.h'].contains(ext)) return 'c';
    if (ext == '.java') return 'java';
    if (['.html', '.htm'].contains(ext)) return 'html';
    return _currentProject?.language ?? 'python';
  }

  void _onFileSelected(VirtualFile file) {
    if (file.isPlugin) return;
    if (_selectedFile != null && _currentProject != null) {
      final idx = _currentProject!.files.indexWhere((f) => f.id == _selectedFile!.id);
      if (idx >= 0) _currentProject!.files[idx] = _selectedFile!;
      final openIdx = _openFiles.indexWhere((f) => f.id == _selectedFile!.id);
      if (openIdx >= 0) _openFiles[openIdx] = _selectedFile!;
    }
    final projectFile = _currentProject?.files.firstWhere((f) => f.id == file.id, orElse: () => file) ?? file;
    final lang = _languageForFile(projectFile);
    final newMode = _highlightModes[lang] ?? _highlightModes['python']!;
    setState(() {
      _selectedFile = projectFile;
      _selectedLanguage = lang;
      _activeTabFileId = projectFile.id;
      _codeController.language = newMode;
      _codeController.text = projectFile.content;
      if (!_openFiles.any((f) => f.id == projectFile.id)) {
        _openFiles.add(projectFile);
      }
    });
  }

  void _closeFileTab(String fileId) {
    if (_selectedFile != null && _currentProject != null) {
      final idx = _currentProject!.files.indexWhere((f) => f.id == _selectedFile!.id);
      if (idx >= 0) _currentProject!.files[idx] = _selectedFile!;
      final openIdx = _openFiles.indexWhere((f) => f.id == _selectedFile!.id);
      if (openIdx >= 0) _openFiles[openIdx] = _selectedFile!;
    }
    if (_openFiles.length == 1) {
      setState(() {
        _openFiles.clear();
        _activeTabFileId = null;
        _selectedFile = null;
        _codeController.text = '';
      });
      return;
    }
    final idx = _openFiles.indexWhere((f) => f.id == fileId);
    if (idx < 0) return;
    VirtualFile? nextFile;
    if (fileId == _activeTabFileId) {
      nextFile = idx > 0 ? _openFiles[idx - 1] : _openFiles[idx + 1];
    }
    setState(() {
      _openFiles.removeAt(idx);
      if (nextFile != null) {
        _onFileSelected(nextFile);
      }
    });
  }

  void _onCodeChanged(String code) {
    if (_selectedFile != null) {
      _selectedFile = _selectedFile!.copyWith(content: code);
    }
  }

  Future<void> _saveCurrentProject() async {
    if (_currentProject == null) return;
    _currentProject!.updatedAt = DateTime.now();
    if (_selectedFile != null) {
      final idx = _currentProject!.files.indexWhere((f) => f.id == _selectedFile!.id);
      if (idx >= 0) _currentProject!.files[idx] = _selectedFile!;
      final openIdx = _openFiles.indexWhere((f) => f.id == _selectedFile!.id);
      if (openIdx >= 0) _openFiles[openIdx] = _selectedFile!;
    }
    _openFiles.removeWhere((f) => !_currentProject!.files.any((pf) => pf.id == f.id));
    if (_activeTabFileId != null && !_currentProject!.files.any((f) => f.id == _activeTabFileId)) {
      _activeTabFileId = null;
      _selectedFile = _openFiles.isNotEmpty ? _openFiles.last : null;
      if (_selectedFile != null) {
        _codeController.text = _selectedFile!.content;
      } else {
        _codeController.text = '';
      }
    }
    await VirtualStorageService.saveProject(_currentProject!);
    await _loadProjects();
  }

  void _createNewProject() {
    final nameCtrl = TextEditingController();
    final langCtrl = TextEditingController(text: 'python');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('New Project', style: TextStyle(color: Color(0xFFF8F8F2))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Color(0xFFF8F8F2), fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Project name',
                hintStyle: const TextStyle(color: Color(0xFF6272A4)),
                filled: true,
                fillColor: const Color(0xFF282A36),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: langCtrl,
              style: const TextStyle(color: Color(0xFFF8F8F2), fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'python / javascript / cpp / java',
                hintStyle: const TextStyle(color: Color(0xFF6272A4)),
                filled: true,
                fillColor: const Color(0xFF282A36),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6272A4))),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final lang = langCtrl.text.trim().toLowerCase();
              if (name.isNotEmpty) {
                final langId = SupportedLanguages.getById(lang) != null ? lang : 'python';
                final langModel = SupportedLanguages.getById(langId);
                final project = VirtualProject.create(
                  name: name,
                  language: langId,
                  files: [
                    VirtualFile(
                      id: '${DateTime.now().millisecondsSinceEpoch}_main',
                      name: VirtualProject.defaultEntryFile(langId),
                      content: langModel?.defaultCode ?? '',
                    ),
                  ],
                );
                await VirtualStorageService.saveProject(project);
                if (mounted) {
                  Navigator.pop(ctx);
                  _onProjectSelected(project);
                  await _loadProjects();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF50FA7B)),
            child: const Text('Create', style: TextStyle(color: Color(0xFF1E1E2E))),
          ),
        ],
      ),
    );
  }

  void _runCode() {
    if (_codeController.text.trim().isEmpty) return;
    final ext = _selectedFile?.extension.toLowerCase() ?? '';
    if (ext == '.html' || ext == '.htm') {
      _showHtmlPreview(_codeController.text);
      return;
    }
    // Flush editor content back to project model and persist to disk before run
    if (_selectedFile != null && _currentProject != null) {
      final idx = _currentProject!.files.indexWhere((f) => f.id == _selectedFile!.id);
      if (idx >= 0) _currentProject!.files[idx] = _selectedFile!;
      final openIdx = _openFiles.indexWhere((f) => f.id == _selectedFile!.id);
      if (openIdx >= 0) _openFiles[openIdx] = _selectedFile!;
      VirtualStorageService.saveProject(_currentProject!);
    }
    setState(() {
      _terminalRunKey++;
      _showTerminal = true;
      _terminalTab = 0;
    });
  }


  void _showHtmlPreview(String html) {
    final files = _currentProject?.files ?? [];
    final cssFiles = files.where((f) => f.name.endsWith('.css'));
    final jsFiles = files.where((f) => f.name.endsWith('.js'));
    var injected = html;
    for (final f in cssFiles) {
      final name = f.name;
      final content = f.content;
      for (final href in [name, './$name', '../$name']) {
        injected = injected.replaceAll('<link rel="stylesheet" href="$href">', '<style>$content</style>');
        injected = injected.replaceAll("<link rel='stylesheet' href='$href'>", '<style>$content</style>');
      }
    }
    for (final f in jsFiles) {
      final name = f.name;
      final content = f.content;
      for (final src in [name, './$name', '../$name']) {
        injected = injected.replaceAll('<script src="$src"></script>', '<script>$content</script>');
        injected = injected.replaceAll("<script src='$src'></script>", '<script>$content</script>');
      }
    }
    final wvController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(injected);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF282A36),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.html, size: 14, color: Color(0xFF50FA7B)),
                  const SizedBox(width: 6),
                  const Text('HTML Preview', style: TextStyle(color: Color(0xFFF8F8F2), fontSize: 12, fontFamily: 'monospace')),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, size: 14, color: Color(0xFF6272A4)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                child: WebViewWidget(controller: wvController),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _ensureServerProject() async {
    if (_currentProject == null) return null;
    final localId = _currentProject!.id;
    var serverId = _serverIdForProject(localId);
    if (serverId == null) {
      serverId = await ProjectSyncService.createServerProject(_currentProject!);
      if (serverId != null) _setServerId(localId, serverId);
    }
    return serverId;
  }

  Future<bool> _pushFilesToServer(String serverId) async {
    if (_currentProject == null) return false;
    final ok = await ProjectSyncService.pushFiles(serverId, _currentProject!);
    if (ok) _currentProject!.isSynced = true;
    return ok;
  }

  Future<void> _pushToServer() async {
    if (_currentProject == null) return;
    await _saveCurrentProject();
    final serverProjects = await ProjectSyncService.listServerProjects();
    if (!mounted) return;

    final localName = _currentProject!.name;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Push to Server', style: TextStyle(color: Color(0xFFF8F8F2))),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Replace an existing project or create a new one:',
                  style: TextStyle(color: Color(0xFF6272A4), fontSize: 11, fontFamily: 'monospace')),
              const SizedBox(height: 8),
              ...serverProjects.map((sp) => ListTile(
                dense: true,
                leading: const Icon(Icons.cloud_upload, color: Color(0xFFBD93F9), size: 18),
                title: Text(sp.name, style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 13)),
                subtitle: Text(sp.framework, style: const TextStyle(color: Color(0xFF6272A4), fontSize: 10)),
                onTap: () => Navigator.pop(ctx, sp.id),
              )),
              const Divider(color: Color(0xFF44475A)),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add_circle_outline, color: Color(0xFF50FA7B), size: 18),
                title: const Text('Create new', style: TextStyle(color: Color(0xFF50FA7B), fontSize: 13)),
                subtitle: Text('"$localName"', style: const TextStyle(color: Color(0xFF6272A4), fontSize: 10)),
                onTap: () => Navigator.pop(ctx, '__new__'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    String? serverId;
    if (choice == '__new__') {
      var name = localName;
      final existingNames = serverProjects.map((p) => p.name).toSet();
      if (existingNames.contains(name)) {
        var counter = 2;
        while (existingNames.contains('${name}_$counter')) { counter++; }
        name = '${name}_$counter';
      }
      final renamed = _currentProject!.name != name;
      final proj = renamed
          ? VirtualProject(
              id: _currentProject!.id,
              name: name,
              language: _currentProject!.language,
              createdAt: _currentProject!.createdAt,
              updatedAt: _currentProject!.updatedAt,
              files: _currentProject!.files,
              folders: _currentProject!.folders,
            )
          : _currentProject!;
      serverId = await ProjectSyncService.createServerProject(proj);
      if (serverId == null) {
        if (mounted) _showSnack('Failed to create project on server', const Color(0xFFFF5555));
        return;
      }
      _setServerId(_currentProject!.id, serverId);
    } else {
      serverId = choice;
    }
    if (serverId == null) return;
    final ok = await _pushFilesToServer(serverId);
    if (mounted) {
      _showSnack(ok ? 'Pushed to server' : 'Failed to push files', ok ? const Color(0xFF50FA7B) : const Color(0xFFFF5555));
    }
  }

  String? _getServerProjectId() {
    if (_currentProject == null) return null;
    return _serverIdForProject(_currentProject!.id);
  }

  Future<void> _pullFromServer() async {
    final serverProjects = await ProjectSyncService.listServerProjects();
    if (!mounted) return;
    if (serverProjects.isEmpty) {
      if (mounted) _showSnack('No server projects', const Color(0xFF6272A4));
      return;
    }
    if (!mounted) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Pull from Server', style: TextStyle(color: Color(0xFFF8F8F2))),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: serverProjects.length,
            itemBuilder: (ctx, i) {
              final sp = serverProjects[i];
              return ListTile(
                leading: const Icon(Icons.cloud_download, color: Color(0xFF8BE9FD), size: 18),
                title: Text(sp.name, style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 13)),
                subtitle: Text(sp.framework, style: const TextStyle(color: Color(0xFF6272A4), fontSize: 10)),
                onTap: () => Navigator.pop(ctx, i),
                trailing: GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF1E1E2E),
                        title: const Text('Delete project?', style: TextStyle(color: Color(0xFFFF5555))),
                        content: Text('Delete "${sp.name}" from server?', style: const TextStyle(color: Color(0xFFF8F8F2))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6272A4)))),
                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFFF5555)))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ProjectSyncService.deleteServerProject(sp.id);
                      if (mounted) _showSnack('Deleted from server', const Color(0xFFFF5555));
                      Navigator.pop(ctx);
                      _pullFromServer();
                    }
                  },
                  child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFFF5555)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6272A4))),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final sp = serverProjects[selected];
    final project = await ProjectSyncService.pullProject(sp.id);
    if (project == null) {
      if (mounted) _showSnack('Failed to pull project', const Color(0xFFFF5555));
      return;
    }
    await VirtualStorageService.saveProject(project);
    await _loadProjects();
    _onProjectSelected(project);
    if (mounted) _showSnack('Pulled "${project.name}"', const Color(0xFF50FA7B));
  }

  // ===== SEPARATE GitHub sync (does NOT touch the backend push/pull) =====
  Future<void> _openGithubDialog() async {
    if (_currentProject == null) {
      if (mounted) _showSnack('Open a project first', const Color(0xFF6272A4));
      return;
    }
    final gh = GithubSyncService.instance;
    final token = await gh.resolveToken();
    if (!mounted) return;

    if (token == null) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Connect GitHub',
              style: TextStyle(color: Color(0xFFF8F8F2))),
          content: const Text(
            'Add a GitHub Personal Access Token in Services Management to '
            'push & pull real files.',
            style: TextStyle(color: Color(0xFF6272A4), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later',
                  style: TextStyle(color: Color(0xFF6272A4))),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context)
                    .pushNamed(AppRoutes.servicesManagement);
              },
              child: const Text('Open Services',
                  style: TextStyle(color: Color(0xFF50FA7B))),
            ),
          ],
        ),
      );
      return;
    }

    List<GitHubRepo>? repos = await gh.listRepos();
    GitHubRepo? chosen;
    String? selectedEnv;
    bool busy = false;
    String? err;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('GitHub Sync',
              style: TextStyle(color: Color(0xFFF8F8F2))),
          content: SizedBox(
            width: double.maxFinite,
            child: Builder(
              builder: (_) {
                if (repos == null) {
                  return const SizedBox(
                    height: 80,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF50FA7B)),
                    ),
                  );
                }
                if (repos!.isEmpty) {
                  return const Text('No repositories found.',
                      style: TextStyle(color: Color(0xFF6272A4)));
                }
                if (chosen == null) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: repos!.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.code,
                          color: Color(0xFF50FA7B), size: 18),
                      title: Text(repos![i].fullName,
                          style: const TextStyle(
                              color: Color(0xFFF8F8F2), fontSize: 13)),
                      subtitle: Text('branch: ${repos![i].defaultBranch}',
                          style: const TextStyle(
                              color: Color(0xFF6272A4), fontSize: 10)),
                      onTap: () => set(() {
                        chosen = repos![i];
                        selectedEnv = null;
                      }),
                    ),
                  );
                }
                // .env selection step (one file, or none)
                final envFiles = _currentProject!.files
                    .where((f) =>
                        f.name == '.env' ||
                        f.name.endsWith('.env') ||
                        f.name.contains('.env.'))
                    .toList();
                final files = _currentProject!.files;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repository: ${chosen!.fullName}',
                        style: const TextStyle(
                            color: Color(0xFF50FA7B),
                            fontSize: 12,
                            fontFamily: 'monospace')),
                    const SizedBox(height: 6),
                    const Text(
                        'Push the whole project, plus attach one .env file '
                        'to the backend for hosting:',
                        style: TextStyle(
                            color: Color(0xFF6272A4), fontSize: 12)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 240,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          RadioListTile<String?>(
                            dense: true,
                            activeColor: const Color(0xFF50FA7B),
                            title: const Text('No .env file',
                                style: TextStyle(
                                    color: Color(0xFFF8F8F2), fontSize: 12)),
                            value: null,
                            groupValue: selectedEnv,
                            onChanged: (v) => set(() => selectedEnv = v),
                          ),
                          ...envFiles.map((f) => RadioListTile<String?>(
                                dense: true,
                                activeColor: const Color(0xFF50FA7B),
                                title: Text(f.name,
                                    style: const TextStyle(
                                        color: Color(0xFFF8F8F2),
                                        fontSize: 12)),
                                value: f.name,
                                groupValue: selectedEnv,
                                onChanged: (v) => set(() => selectedEnv = v),
                              )),
                          if (envFiles.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                  'No .env files detected in this project.',
                                  style: TextStyle(
                                      color: Color(0xFF6272A4), fontSize: 12)),
                            ),
                          const Divider(color: Color(0xFF44475A)),
                          ...files.map((f) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 2),
                                child: Text('• ${f.name}',
                                    style: const TextStyle(
                                        color: Color(0xFF6272A4),
                                        fontSize: 11)),
                              )),
                        ],
                      ),
                    ),
                    if (err != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(err!,
                            style: const TextStyle(
                                color: Color(0xFFFF5555), fontSize: 12)),
                      ),
                  ],
                );
              },
            ),
          ),
          actions: [
            if (chosen != null)
              TextButton(
                onPressed: () => set(() {
                  chosen = null;
                  selectedEnv = null;
                  err = null;
                }),
                child: const Text('Back',
                    style: TextStyle(color: Color(0xFF6272A4))),
              ),
                if (chosen != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        set(() => busy = true);
                        try {
                          // Push the whole project to GitHub.
                          await gh.push(chosen!.fullName,
                              chosen!.defaultBranch, _currentProject!);
                          // Attach the chosen .env file to the backend so
                          // hosting created "from GitHub" includes it.
                          if (selectedEnv != null) {
                            final envFile = _currentProject!.files
                                .where((f) => f.name == selectedEnv)
                                .firstOrNull;
                            final serverId = await _ensureServerProject();
                            if (serverId != null && envFile != null) {
                              await ProjectSyncService.pushEnv(
                                  serverId, envFile.name, envFile.content);
                            }
                          }
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          _showSnack(
                              'Pushed "${_currentProject!.name}" to GitHub',
                              const Color(0xFF50FA7B));
                        } catch (e) {
                          set(() {
                            busy = false;
                            err = e
                                .toString()
                                .replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF50FA7B)),
                      )
                    : const Text('Push to GitHub',
                        style: TextStyle(color: Color(0xFF50FA7B))),
              ),
            if (chosen != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        set(() => busy = true);
                        try {
                          final project = await gh.pull(
                              chosen!.fullName, chosen!.defaultBranch);
                          await VirtualStorageService.saveProject(project);
                          await _loadProjects();
                          _onProjectSelected(project);
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          _showSnack('Pulled "${project.name}"',
                              const Color(0xFF50FA7B));
                        } catch (e) {
                          set(() {
                            busy = false;
                            err = e
                                .toString()
                                .replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: const Text('Pull repo',
                    style: TextStyle(color: Color(0xFF8BE9FD))),
              ),
          ],
        ),
      ),
    );
  }

  void _exportProject() {
    if (_currentProject == null) return;
    _exportProjectAsync();
  }

  Future<void> _exportProjectAsync() async {
    if (_currentProject == null) return;
    try {
      // Build ZIP archive in memory
      final archive = Archive();
      for (final file in _currentProject!.files) {
        final contentBytes = utf8.encode(file.content);
        archive.addFile(ArchiveFile(file.name, contentBytes.length, contentBytes));
      }
      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        if (mounted) _showSnack('Failed to create archive', const Color(0xFFFF5555));
        return;
      }

      // Write ZIP to temp file
      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/${_currentProject!.name}.zip';
      await File(zipPath).writeAsBytes(zipBytes.toList());

      // Share via system share sheet
      await Share.shareXFiles(
        [XFile(zipPath, mimeType: 'application/zip')],
        text: '${_currentProject!.name} — Exported Project',
      );

      // Clean up temp file
      try {
        await File(zipPath).delete();
      } catch (_) {}

      if (mounted) _showSnack('Project exported', const Color(0xFF50FA7B));
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e', const Color(0xFFFF5555));
    }
  }

  void _importProject() {
    _importProjectAsync();
  }

  Future<void> _importProjectAsync() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) _showSnack('Failed to read file', const Color(0xFFFF5555));
        return;
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      final projectName = file.name.replaceAll('.zip', '');
      final now = DateTime.now();
      final files = <VirtualFile>[];

      for (final entry in archive) {
        if (entry.isFile) {
          final raw = entry.content;
          String content;
          if (raw is List<int>) {
            content = utf8.decode(raw, allowMalformed: true);
          } else if (raw != null) {
            content = raw.toString();
          } else {
            content = '';
          }
          files.add(VirtualFile(
            id: '${now.millisecondsSinceEpoch}_${files.length}',
            name: entry.name,
            content: content,
          ));
        }
      }

      if (files.isEmpty) {
        if (mounted) _showSnack('No files found in archive', const Color(0xFFFF5555));
        return;
      }

      final project = VirtualProject(
        id: now.millisecondsSinceEpoch.toString(),
        name: projectName,
        language: 'python',
        createdAt: now,
        updatedAt: now,
        files: files,
      );

      await VirtualStorageService.saveProject(project);
      await _loadProjects();
      if (mounted) {
        _onProjectSelected(project);
        _showSnack('Imported "${projectName}" (${files.length} files)', const Color(0xFF50FA7B));
      }
    } catch (e) {
      if (mounted) _showSnack('Import failed: $e', const Color(0xFFFF5555));
    }
  }

  void _onLanguageSelected(String lang) {
    setState(() => _selectedLanguage = lang);
    if (_currentProject != null) _currentProject!.language = lang;
    _codeController.language = _highlightModes[lang];
  }

  void _showAiAgent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF282A36),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBD93F9).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFFBD93F9), size: 22),
                ),
                const SizedBox(width: 12),
                const Text('AI Assistant', style: TextStyle(color: Color(0xFFF8F8F2), fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: Text(
                  'Coming soon...\nAsk for code generation, debugging, or refactoring.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6272A4), fontFamily: 'monospace', height: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Color(0xFFF8F8F2), fontFamily: 'monospace', fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Ask AI anything...',
                        hintStyle: TextStyle(color: Color(0xFF6272A4)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFF50FA7B), size: 20),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPlugins() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF282A36),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _PluginMarketplace(projectId: _currentProject?.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IntroCheck(
      featureKey: codingIdeFeatureKey,
      featureIcon: codingIdeFeatureIcon,
      featureTitle: codingIdeFeatureTitle,
      featureSubtitle: codingIdeFeatureSubtitle,
      steps: codingIdeIntroSteps,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E2E),
      drawer: Drawer(
        width: 260,
        backgroundColor: const Color(0xFF282A36),
        child: SafeArea(
          child: Column(
            children: [
              _buildSidebarTabs(),
              Expanded(
                child: IndexedStack(
                  index: _sidebarTab,
                  children: [
                    _buildProjectList(),
                    _buildFileTreePanel(),
                    _buildSearchPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return Column(
              children: [
                _buildTopBar(isWide),
                Expanded(child: _buildBody(isWide)),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildTopBar(bool isWide) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF282A36),
        border: Border(bottom: BorderSide(color: Color(0xFF44475A), width: 0.5)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (menuCtx) => _topBarBtn(
              Icons.menu_rounded,
              isWide
                  ? () => setState(() => _showSidebar = !_showSidebar)
                  : () => Scaffold.of(menuCtx).openDrawer(),
              active: isWide && _showSidebar,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF50FA7B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 14, color: Color(0xFF50FA7B)),
                SizedBox(width: 6),
                Text('SIDE', style: TextStyle(color: Color(0xFF50FA7B), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
              ],
            ),
          ),
          if (_currentProject != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF44475A).withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _currentProject!.name,
                style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            if (_currentProject!.isSynced)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.cloud_done, size: 12, color: Color(0xFF8BE9FD)),
              ),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _topBarBtn(Icons.auto_awesome, _showAiAgent, color: const Color(0xFFBD93F9)),
                  const SizedBox(width: 2),
                  _topBarBtn(Icons.extension_outlined, _showPlugins, color: const Color(0xFF8BE9FD)),
                  const SizedBox(width: 2),
                  if (_currentProject != null) ...[
                    _topBarBtn(Icons.file_copy_outlined, _exportProject, color: const Color(0xFFF1FA8C)),
                    const SizedBox(width: 2),
                    _topBarBtn(Icons.file_download_outlined, _importProject, color: const Color(0xFFF1FA8C)),
                    const SizedBox(width: 2),
                  ],
                  _topBarBtn(Icons.emoji_events_outlined, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SideChallengesScreen()));
                  }, color: const Color(0xFFFFB86C)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBarBtn(IconData icon, VoidCallback onTap, {Color? color, bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF50FA7B).withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color ?? (active ? const Color(0xFF50FA7B) : const Color(0xFF6272A4))),
      ),
    );
  }

  Widget _buildBody(bool isWide) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWide && _showSidebar) _buildSidebar(),
        if (isWide && _showSidebar) _buildDivider(),
        Expanded(child: _buildMainPanel()),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, color: const Color(0xFF44475A).withOpacity(0.4));
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 240,
      child: Column(
        children: [
          _buildSidebarTabs(),
          Expanded(
            child: IndexedStack(
              index: _sidebarTab,
              children: [
                _buildProjectList(),
                _buildFileTreePanel(),
                _buildSearchPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTabs() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF282A36),
        border: Border(bottom: BorderSide(color: Color(0xFF44475A), width: 0.5)),
      ),
      child: Row(
        children: [
          _sidebarTabBtn(0, Icons.folder_outlined, 'Projects'),
          const SizedBox(width: 2),
          _sidebarTabBtn(1, Icons.description_outlined, 'Files'),
          const SizedBox(width: 2),
          _sidebarTabBtn(2, Icons.search, 'Search'),
          const Spacer(),
          if (_currentProject != null)
            GestureDetector(
              onTap: () {
                setState(() { _currentProject = null; _selectedFile = null; _sidebarTab = 0; });
              },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 10, color: Color(0xFF6272A4)),
                ),
            ),
        ],
      ),
    );
  }

  Widget _sidebarTabBtn(int index, IconData icon, String label) {
    final active = _sidebarTab == index;
    return GestureDetector(
      onTap: () => setState(() => _sidebarTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? const Color(0xFF50FA7B) : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? const Color(0xFF50FA7B) : const Color(0xFF6272A4)),
            const SizedBox(width: 3),
            Text(label,
              style: TextStyle(
                color: active ? const Color(0xFFF8F8F2) : const Color(0xFF6272A4),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList() {
    return Column(
      children: [
        _buildListHeader('Projects', Icons.folder_outlined, _createNewProject),
        Expanded(
          child: _projects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_off_outlined, size: 36, color: const Color(0xFF6272A4).withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text('No projects yet', style: TextStyle(color: Color(0xFF6272A4), fontFamily: 'monospace', fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _projects.length,
                  itemBuilder: (ctx, i) => _buildProjectItem(_projects[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildProjectItem(VirtualProject project) {
    final active = _currentProject?.id == project.id;
    return GestureDetector(
      onTap: () => _onProjectSelected(project),
      onLongPress: () => _projectCtx(project),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 4, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF50FA7B).withOpacity(0.08) : null,
          border: Border(left: BorderSide(color: active ? const Color(0xFF50FA7B) : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_rounded, size: 16,
              color: active ? const Color(0xFF50FA7B) : const Color(0xFFF1FA8C)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name,
                    style: TextStyle(
                      color: active ? const Color(0xFF50FA7B) : const Color(0xFFF8F8F2),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF44475A).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(project.language,
                          style: const TextStyle(color: Color(0xFF6272A4), fontSize: 9, fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 6),
                      Text('${project.files.length} file${project.files.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: Color(0xFF6272A4), fontSize: 9)),
                    ],
                  ),
                ],
              ),
            ),
            if (project.isSynced)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.cloud_done, size: 10, color: Color(0xFF8BE9FD)),
              ),
            GestureDetector(
              onTap: () => _projectCtx(project),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.more_vert, size: 14, color: Color(0xFF6272A4)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader(String title, IconData icon, VoidCallback onAdd) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6272A4)),
          const SizedBox(width: 6),
          Text(title,
            style: const TextStyle(
              color: const Color(0xFFF8F8F2),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF50FA7B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.add, size: 14, color: Color(0xFF50FA7B)),
            ),
          ),
        ],
      ),
    );
  }

  void _projectCtx(VirtualProject project) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF282A36),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(project.name, style: const TextStyle(color: Color(0xFFF8F8F2), fontFamily: 'monospace', fontSize: 13)),
            ),
            const Divider(color: Color(0xFF44475A), height: 1),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF50FA7B), size: 20),
              title: const Text('Push to Server', style: TextStyle(color: Color(0xFFF8F8F2), fontSize: 13)),
              onTap: () async {
                Navigator.pop(ctx);
                final serverId = await ProjectSyncService.createServerProject(project);
                if (serverId != null) { await VirtualStorageService.markSynced(project.id); project.isSynced = true; if (mounted) setState(() {}); }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFFF5555), size: 20),
              title: const Text('Delete Project', style: TextStyle(color: Color(0xFFF8F8F2), fontSize: 13)),
              onTap: () async {
                Navigator.pop(ctx);
                await VirtualStorageService.deleteProject(project.id);
                if (_currentProject?.id == project.id) setState(() { _currentProject = null; _selectedFile = null; });
                await _loadProjects();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF50FA7B).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF50FA7B)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFF50FA7B), fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTreePanel() {
    if (_currentProject == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 36, color: const Color(0xFF6272A4).withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text('No project open', style: TextStyle(color: Color(0xFF6272A4), fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 12),
            _buildBtn('Browse Projects', Icons.folder_outlined, () => setState(() => _sidebarTab = 0)),
          ],
        ),
      );
    }
    return SideFileTree(
      project: _currentProject!,
      selectedFileId: _selectedFile?.id,
      onFileSelected: _onFileSelected,
      onFilesChanged: () {
        final project = _currentProject;
        if (project != null) {
          for (var i = 0; i < _openFiles.length; i++) {
            final matches = project.files.where((f) => f.id == _openFiles[i].id);
            if (matches.isNotEmpty) _openFiles[i] = matches.first;
          }
          if (_selectedFile != null) {
            final match = project.files.firstWhere((f) => f.id == _selectedFile!.id, orElse: () => _selectedFile!);
            _selectedFile = match;
            _codeController.text = match.content;
          }
        }
        _saveCurrentProject();
        setState(() {});
      },
      onExport: _exportProject,
      onImport: _importProject,
    );
  }

  Widget _buildSearchPanel() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const TextField(
            style: TextStyle(color: Color(0xFFF8F8F2), fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search code...',
              hintStyle: TextStyle(color: Color(0xFF6272A4)),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Color(0xFF6272A4), size: 16),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text('Search across all files',
              style: TextStyle(color: const Color(0xFF6272A4).withOpacity(0.6), fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Widget _buildMainPanel() {
    return Column(
      children: [
        _buildEditorBar(),
        Expanded(child: _buildEditorArea()),
      ],
    );
  }

  Widget _buildEditorBar() {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFF282A36),
        border: Border(bottom: BorderSide(color: Color(0xFF44475A), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _openFiles.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _openFiles.length,
                    itemBuilder: (ctx, i) => _buildFileTab(_openFiles[i]),
                  ),
          ),
          _barButton(Icons.save_outlined, 'Save', const Color(0xFF50FA7B), () async {
            await _saveCurrentProject();
            if (mounted) _showSnack('Saved', const Color(0xFF50FA7B));
          }),
          _barButton(Icons.cloud_upload_outlined, 'Push to server', const Color(0xFFBD93F9), _pushToServer),
          _barButton(Icons.cloud_download_outlined, 'Pull from server', const Color(0xFF8BE9FD), _pullFromServer),
          _barButton(Icons.code_rounded, 'GitHub', const Color(0xFF50FA7B), _openGithubDialog),
          _barButton(_showTerminal ? Icons.terminal : Icons.terminal_outlined, 'Toggle terminal', const Color(0xFF8BE9FD), () => setState(() => _showTerminal = !_showTerminal)),
          SideRunButton(isRunning: false, onPressed: _runCode),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _barButton(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    );
  }

  Widget _buildFileTab(VirtualFile file) {
    final isActive = file.id == _activeTabFileId;
    return GestureDetector(
      onTap: () => _onFileSelected(file),
      child: Container(
        height: 34,
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E1E2E) : Colors.transparent,
          border: Border(
            top: BorderSide(color: isActive ? const Color(0xFF50FA7B) : Colors.transparent, width: 2),
            right: BorderSide(color: const Color(0xFF44475A).withOpacity(0.3), width: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 11, color: const Color(0xFF6272A4)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                file.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? const Color(0xFFF8F8F2) : const Color(0xFF6272A4),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _closeFileTab(file.id),
              child: Icon(Icons.close, size: 10, color: isActive ? const Color(0xFFF8F8F2) : const Color(0xFF6272A4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorArea() {
    return Column(
      children: [
        Expanded(child: _buildEditor()),
        _buildTerminalBar(),
        Offstage(
          offstage: !_showTerminal,
          child: SizedBox(
            height: 180,
            child: _buildTerminal(),
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF44475A).withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SideCodeEditor(
        controller: _codeController,
        language: _selectedLanguage,
        onChanged: _onCodeChanged,
        fileName: _selectedFile?.name,
      ),
    );
  }

  Widget _buildTerminalBar() {
    return GestureDetector(
      onTap: () {
        if (mounted) setState(() => _showTerminal = !_showTerminal);
      },
      child: Container(
        height: 20,
        color: const Color(0xFF282A36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: _showTerminal ? const Color(0xFF50FA7B) : const Color(0xFF6272A4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Spacer(),
            Container(
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF6272A4).withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminal() {
    if (_currentProject == null) {
      return const SizedBox.shrink();
    }
    final serverId = _getServerProjectId();
    if (serverId != null) {
      return InteractiveTerminal(
        projectId: serverId,
        onClose: () => setState(() => _showTerminal = false),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        border: Border(top: BorderSide(color: const Color(0xFF44475A).withOpacity(0.3))),
      ),
      child: Column(
        children: [
          _buildTerminalHeader(onClose: () => setState(() => _showTerminal = false)),
          Expanded(child: _terminalTab == 0 ? _buildOutputTab() : _buildCommandTab()),
        ],
      ),
    );
  }

  Widget _buildTerminalHeader({required VoidCallback onClose}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF282A36),
        border: Border(bottom: BorderSide(color: Color(0xFF44475A), width: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 11, color: Color(0xFF50FA7B)),
          const SizedBox(width: 6),
          _terminalTabBtn('OUTPUT', 0),
          const SizedBox(width: 2),
          _terminalTabBtn('COMMAND', 1),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, size: 10, color: Color(0xFF6272A4)),
          ),
        ],
      ),
    );
  }

  Widget _terminalTabBtn(String label, int tab) {
    final active = _terminalTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _terminalTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF50FA7B).withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF50FA7B) : const Color(0xFF6272A4),
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Map<String, String>? _buildExecutionFiles() {
    if (_currentProject == null) return null;
    final files = {for (final f in _currentProject!.files) f.name: f.content};
    if (_selectedFile != null) {
      files[_selectedFile!.name] = _codeController.text;
    }
    return files;
  }

  Widget _buildOutputTab() {
    final code = _codeController.text;
    final language = _selectedLanguage;
    return InteractiveExecutionTerminal(
      key: ValueKey('exec-$_terminalRunKey'),
      code: code,
      language: language,
      files: _buildExecutionFiles(),
      entryFile: _selectedFile?.name,
    );
  }

  Widget _buildCommandTab() {
    final hasProject = _selectedServerProject != null;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ServerProjectInfo>(
                  value: _selectedServerProject,
                  dropdownColor: const Color(0xFF282A36),
                  style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    labelText: 'Server Project',
                    labelStyle: const TextStyle(color: Color(0xFF6272A4)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF44475A)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFF282A36),
                    isDense: true,
                  ),
                  items: _serverProjects.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} (${p.framework})', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: _selectServerProject,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _loadServerProjects,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF44475A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.refresh, size: 14, color: Color(0xFF6272A4)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: hasProject
              ? InteractiveTerminal(projectId: _selectedServerProject!.id)
              : Center(
                  child: Text(
                    'Select a server project above',
                    style: const TextStyle(
                        color: Color(0xFF6272A4),
                        fontSize: 11,
                        fontFamily: 'monospace'),
                  ),
                ),
        ),
       ],
     );
   }
}

// ── Plugin Marketplace Widget ──────────────────────────

class _PluginMarketplace extends StatefulWidget {
  final String? projectId;
  const _PluginMarketplace({this.projectId});

  @override
  State<_PluginMarketplace> createState() => _PluginMarketplaceState();
}

class _PluginMarketplaceState extends State<_PluginMarketplace> {
  List<SidePlugin> _allPlugins = [];
  List<SidePlugin> _installedPlugins = [];
  List<SidePlugin> _projectPlugins = [];
  bool _loading = true;
  String _search = '';
  String? _languageFilter;

  static const _languages = ['python', 'javascript', 'html', 'cpp', 'c', 'java', 'flutter'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      SidePluginService.getPlugins(),
      SidePluginService.getInstalledPlugins(),
      if (widget.projectId != null) SidePluginService.getProjectPlugins(widget.projectId!) else Future.value(<SidePlugin>[]),
    ]);
    if (!mounted) return;
    setState(() {
      _allPlugins = results[0] as List<SidePlugin>;
      _installedPlugins = results[1] as List<SidePlugin>;
      _projectPlugins = results.length > 2 ? results[2] as List<SidePlugin> : [];
      _loading = false;
    });
  }

  bool _isInstalled(String pluginId) => _installedPlugins.any((p) => p.id == pluginId);
  bool _isInProject(String pluginId) => _projectPlugins.any((p) => p.id == pluginId);

  List<SidePlugin> get _filtered {
    var list = _allPlugins;
    if (_languageFilter != null) {
      list = list.where((p) => p.language == _languageFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8BE9FD).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.extension, color: Color(0xFF8BE9FD), size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Plugin Marketplace', style: TextStyle(color: Color(0xFFF8F8F2), fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF6272A4), size: 18),
                onPressed: _load,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              style: const TextStyle(color: Color(0xFFF8F8F2), fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search plugins...',
                hintStyle: TextStyle(color: Color(0xFF6272A4)),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Color(0xFF6272A4), size: 20),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(height: 8),
          // Language filter chips
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All', null),
                ..._languages.map((l) => _filterChip(l, l)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Plugin list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8BE9FD)))
                : _filtered.isEmpty
                    ? const Center(child: Text('No plugins found', style: TextStyle(color: Color(0xFF6272A4), fontFamily: 'monospace')))
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) => _buildPluginCard(_filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _languageFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _languageFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF8BE9FD).withOpacity(0.15) : const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF8BE9FD) : const Color(0xFF44475A)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF8BE9FD) : const Color(0xFF6272A4),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPluginCard(SidePlugin plugin) {
    final installed = _isInstalled(plugin.id);
    final inProject = _isInProject(plugin.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8BE9FD).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.extension, color: Color(0xFF8BE9FD), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plugin.name, style: const TextStyle(color: Color(0xFFF8F8F2), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                const SizedBox(height: 2),
                Text(plugin.description,
                  style: const TextStyle(color: Color(0xFF6272A4), fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _badge(plugin.language, const Color(0xFFBD93F9)),
                    const SizedBox(width: 6),
                    _badge('v${plugin.version}', const Color(0xFF50FA7B)),
                    if (plugin.author.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _badge(plugin.author, const Color(0xFFFFB86C)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!installed)
            _actionBtn('Install', const Color(0xFF50FA7B), () async {
              final ok = await SidePluginService.installPlugin(plugin.id);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${plugin.name} installed'), backgroundColor: const Color(0xFF50FA7B)));
                _load();
              }
            })
          else if (widget.projectId != null && !inProject)
            _actionBtn('Add', const Color(0xFF8BE9FD), () async {
              final ok = await SidePluginService.addPluginToProject(plugin.id, widget.projectId!);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${plugin.name} added to project'), backgroundColor: const Color(0xFF8BE9FD)));
                _load();
              }
            })
          else if (widget.projectId != null && inProject)
            _actionBtn('Remove', const Color(0xFFFF5555), () async {
              final ok = await SidePluginService.removePluginFromProject(plugin.id, widget.projectId!);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${plugin.name} removed from project'), backgroundColor: const Color(0xFFFF5555)));
                _load();
              }
            })
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6272A4).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Installed', style: TextStyle(color: Color(0xFF6272A4), fontSize: 10, fontFamily: 'monospace')),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontFamily: 'monospace')),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ),
    );
  }
}
