import 'package:flutter/material.dart';
import '../models/code_project.dart';
import '../models/language_model.dart';
import '../services/code_storage_service.dart';
import '../theme/editor_theme.dart';

class SideProjectManager extends StatefulWidget {
  final Function(CodeProject) onProjectSelected;
  final CodeProject? currentProject;

  const SideProjectManager({
    super.key,
    required this.onProjectSelected,
    this.currentProject,
  });

  @override
  State<SideProjectManager> createState() => _SideProjectManagerState();
}

class _SideProjectManagerState extends State<SideProjectManager> {
  List<CodeProject> _projects = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final projects = await CodeStorageService.getAllProjects();
    setState(() {
      _projects = projects;
      _isLoading = false;
    });
  }

  List<CodeProject> get _filteredProjects {
    if (_searchQuery.isEmpty) return _projects;
    return _projects
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.language.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _showNewProjectDialog() {
    String name = '';
    String language = 'python';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Project name',
                prefixIcon: Icon(Icons.folder),
              ),
              onChanged: (value) => name = value,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: language,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.code),
              ),
              items: SupportedLanguages.languages.map((lang) {
                return DropdownMenuItem(
                  value: lang.id,
                  child: Row(
                    children: [
                      Icon(lang.icon, size: 16, color: lang.color),
                      const SizedBox(width: 8),
                      Text(lang.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) language = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) {
                final project = CodeProject.create(
                  name: name,
                  language: language,
                  code: SupportedLanguages.getById(language)?.defaultCode ?? '',
                );
                widget.onProjectSelected(project);
                CodeStorageService.saveProject(project);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(CodeProject project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Delete "${project.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await CodeStorageService.deleteProject(project.id);
              Navigator.pop(context);
              _loadProjects();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SideEditorTheme.surfaceDark,
        borderRadius: BorderRadius.circular(SideEditorTheme.borderRadius),
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (_projects.isNotEmpty) _buildSearchBar(),
          Expanded(child: _buildProjectList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: SideEditorTheme.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, size: 16, color: SideEditorTheme.accentOrange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'My Projects',
              style: TextStyle(
                color: SideEditorTheme.textDark,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          GestureDetector(
            onTap: _showNewProjectDialog,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: SideEditorTheme.accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: SideEditorTheme.accentGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(
          color: SideEditorTheme.textDark,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
        decoration: InputDecoration(
          hintText: 'Search projects...',
          hintStyle: const TextStyle(
            color: SideEditorTheme.lineNumberColor,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          prefixIcon: const Icon(Icons.search, size: 16),
          prefixIconColor: SideEditorTheme.lineNumberColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: SideEditorTheme.backgroundDark,
        ),
      ),
    );
  }

  Widget _buildProjectList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: SideEditorTheme.accentGreen),
      );
    }

    final projects = _filteredProjects;

    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.code : Icons.search_off,
              size: 40,
              color: SideEditorTheme.lineNumberColor.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty ? 'No projects yet' : 'No matching projects',
              style: const TextStyle(
                color: SideEditorTheme.lineNumberColor,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showNewProjectDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SideEditorTheme.accentGreen,
                  foregroundColor: SideEditorTheme.backgroundDark,
                  textStyle: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final lang = SupportedLanguages.getById(project.language);
        final isCurrent = widget.currentProject?.id == project.id;

        return Dismissible(
          key: Key(project.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: SideEditorTheme.errorRed.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete, color: SideEditorTheme.errorRed),
          ),
          onDismissed: (_) async {
            await CodeStorageService.deleteProject(project.id);
            _loadProjects();
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (lang?.color ?? Colors.grey).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                lang?.icon ?? Icons.code,
                color: lang?.color ?? Colors.grey,
                size: 18,
              ),
            ),
            title: Text(
              project.name,
              style: TextStyle(
                color: isCurrent
                    ? SideEditorTheme.accentGreen
                    : SideEditorTheme.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${lang?.name ?? project.language}  ${_formatDate(project.updatedAt)}',
              style: const TextStyle(
                color: SideEditorTheme.lineNumberColor,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 16, color: SideEditorTheme.lineNumberColor),
              onSelected: (value) {
                if (value == 'delete') _showDeleteDialog(project);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
            onTap: () {
              widget.onProjectSelected(project);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
