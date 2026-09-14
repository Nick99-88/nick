import 'package:flutter/material.dart';
import '../models/server_models.dart';
import '../services/server_project_service.dart';

class ProjectShareScreen extends StatefulWidget {
  final ServerProject? project;

  const ProjectShareScreen({super.key, this.project});

  @override
  State<ProjectShareScreen> createState() => _ProjectShareScreenState();
}

class _ProjectShareScreenState extends State<ProjectShareScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedFramework = 'python';
  ProjectVisibility _visibility = ProjectVisibility.private;
  List<String> _tags = [];
  bool _isLoading = false;
  List<ServerProject> _myProjects = [];
  List<ServerProject> _exploreProjects = [];
  bool _showMyProjects = true;

  static const List<Map<String, dynamic>> _frameworks = [
    {'id': 'python', 'name': 'Python', 'icon': Icons.code, 'color': Color(0xFF3776AB)},
    {'id': 'fastapi', 'name': 'FastAPI', 'icon': Icons.bolt, 'color': Color(0xFF009688)},
    {'id': 'flask', 'name': 'Flask', 'icon': Icons.local_bar, 'color': Color(0xFF000000)},
    {'id': 'django', 'name': 'Django', 'icon': Icons.music_note, 'color': Color(0xFF092E20)},
    {'id': 'node', 'name': 'Node.js', 'icon': Icons.javascript, 'color': Color(0xFF339933)},
    {'id': 'express', 'name': 'Express', 'icon': Icons.web, 'color': Color(0xFF333333)},
    {'id': 'nextjs', 'name': 'Next.js', 'icon': Icons.web_asset, 'color': Color(0xFF000000)},
    {'id': 'flutter', 'name': 'Flutter', 'icon': Icons.phone_android, 'color': Color(0xFF02569B)},
    {'id': 'java', 'name': 'Java', 'icon': Icons.coffee, 'color': Color(0xFFED8B00)},
    {'id': 'spring', 'name': 'Spring', 'icon': Icons.eco, 'color': Color(0xFF6DB33F)},
    {'id': 'go', 'name': 'Go', 'icon': Icons.code, 'color': Color(0xFF00ADD8)},
    {'id': 'rust', 'name': 'Rust', 'icon': Icons.hardware, 'color': Color(0xFFCE412B)},
    {'id': 'cpp', 'name': 'C++', 'icon': Icons.code, 'color': Color(0xFF00599C)},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _descController.text = widget.project!.description;
      _selectedFramework = widget.project!.framework;
      _visibility = widget.project!.visibility;
      _tags = List.from(widget.project!.tags);
    }
    _loadProjects();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _tagController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final projects = await ServerProjectService.getMyProjects();
    setState(() {
      _myProjects = projects;
      _isLoading = false;
    });
  }

  Future<void> _searchExplore() async {
    final query = _searchController.text.trim();
    setState(() => _isLoading = true);
    final projects = await ServerProjectService.exploreProjects(
      query: query.isNotEmpty ? query : null,
      framework: _selectedFramework,
    );
    setState(() {
      _exploreProjects = projects;
      _isLoading = false;
    });
  }

  Future<void> _createProject() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    final project = await ServerProjectService.createProject(
      name: name,
      description: _descController.text.trim(),
      framework: _selectedFramework,
      visibility: _visibility,
      tags: _tags,
    );

    setState(() => _isLoading = false);

    if (project != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Project "${project.name}" created')),
      );
      _loadProjects();
      Navigator.pop(context, project);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create project')),
      );
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
      _tagController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0.5,
        title: Text(
          widget.project != null ? 'Edit Project' : 'New Server Project',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        actions: [
          if (widget.project != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Project?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && widget.project != null) {
                  await ServerProjectService.deleteProject(widget.project!.id);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Project Name', _buildNameField()),
            const SizedBox(height: 16),
            _buildSection('Description', _buildDescField()),
            const SizedBox(height: 16),
            _buildSection('Framework', _buildFrameworkGrid()),
            const SizedBox(height: 16),
            _buildSection('Visibility', _buildVisibilityToggle()),
            const SizedBox(height: 16),
            _buildSection('Tags', _buildTagSection()),
            const SizedBox(height: 24),
            _buildCreateButton(),
            const SizedBox(height: 32),
            _buildSection('My Projects', _buildMyProjectsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF263238),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: InputDecoration(
        hintText: 'my-awesome-project',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDescField() {
    return TextField(
      controller: _descController,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: 'A brief description of your project...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildFrameworkGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _frameworks.map((fw) {
        final isSelected = _selectedFramework == fw['id'];
        final color = fw['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() => _selectedFramework = fw['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.12) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? color : Colors.grey.withOpacity(0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(fw['icon'] as IconData, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  fw['name'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisibilityToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _visibility = ProjectVisibility.private),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _visibility == ProjectVisibility.private
                      ? const Color(0xFF263238)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 16,
                      color: _visibility == ProjectVisibility.private
                          ? Colors.white
                          : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Private',
                      style: TextStyle(
                        color: _visibility == ProjectVisibility.private
                            ? Colors.white
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _visibility = ProjectVisibility.public),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _visibility == ProjectVisibility.public
                      ? const Color(0xFF263238)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.public,
                      size: 16,
                      color: _visibility == ProjectVisibility.public
                          ? Colors.white
                          : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Public',
                      style: TextStyle(
                        color: _visibility == ProjectVisibility.public
                            ? Colors.white
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText: 'Add tag...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addTag,
              icon: const Icon(Icons.add_circle, color: Color(0xFF263238)),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags.map((tag) => Chip(
              label: Text(tag, style: const TextStyle(fontSize: 11)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => setState(() => _tags.remove(tag)),
              backgroundColor: const Color(0xFF263238).withOpacity(0.08),
              side: BorderSide.none,
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createProject,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF263238),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                widget.project != null ? 'Update Project' : 'Create & Deploy',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
      ),
    );
  }

  Widget _buildMyProjectsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myProjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            'No projects yet. Create your first server project above!',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: _myProjects.map((project) {
        final isRunning = project.isRunning;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isRunning ? const Color(0xFF3FB950).withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isRunning
                      ? const Color(0xFF3FB950).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isRunning ? Icons.play_arrow : Icons.folder,
                  color: isRunning ? const Color(0xFF3FB950) : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ServerProjectService.getFrameworkLabel(project.framework)}  •  ${project.formattedSize}  •  ${project.fileCount} files',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: project.visibility == ProjectVisibility.public
                      ? const Color(0xFF58A6FF).withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  project.visibility == ProjectVisibility.public
                      ? Icons.public
                      : Icons.lock,
                  size: 14,
                  color: project.visibility == ProjectVisibility.public
                      ? const Color(0xFF58A6FF)
                      : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
