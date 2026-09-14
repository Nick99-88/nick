import 'package:flutter/material.dart';
import '../models/server_models.dart';
import '../services/server_project_service.dart';
import '../widgets/server_terminal.dart';
import 'project_share_screen.dart';

class ServerIdeScreen extends StatefulWidget {
  const ServerIdeScreen({super.key});

  @override
  State<ServerIdeScreen> createState() => _ServerIdeScreenState();
}

class _ServerIdeScreenState extends State<ServerIdeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ServerProject> _projects = [];
  ServerProject? _selectedProject;
  List<ProjectFile> _files = [];
  ProjectFile? _selectedFile;
  String? _fileContent;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isContainerStarting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final projects = await ServerProjectService.getMyProjects();
    setState(() {
      _projects = projects;
      _isLoading = false;
    });
  }

  Future<void> _selectProject(ServerProject project) async {
    setState(() {
      _selectedProject = project;
      _isLoading = true;
    });
    final files = await ServerProjectService.getProjectFiles(project.id);
    setState(() {
      _files = files;
      _isLoading = false;
      _selectedFile = null;
      _fileContent = null;
    });
  }

  Future<void> _selectFile(ProjectFile file) async {
    if (file.isDirectory) return;
    setState(() {
      _selectedFile = file;
      _fileContent = null;
    });
    final content = await ServerProjectService.getFileContent(
      _selectedProject!.id,
      file.path,
    );
    setState(() => _fileContent = content ?? '');
  }

  Future<void> _saveFile() async {
    if (_selectedFile == null || _fileContent == null) return;
    setState(() => _isSaving = true);
    await ServerProjectService.saveFileContent(
      _selectedProject!.id,
      _selectedFile!.path,
      _fileContent!,
    );
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved ${_selectedFile!.name}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _startContainer() async {
    if (_selectedProject == null) return;
    setState(() => _isContainerStarting = true);

    final config = ContainerConfig(framework: _selectedProject!.framework);
    final started = await ServerProjectService.startContainer(
      _selectedProject!.id,
      config,
    );

    setState(() {
      _isContainerStarting = false;
      if (started) {
        _selectedProject = _selectedProject!.copyWith(
          containerStatus: ContainerStatus.running,
        );
      }
    });

    if (started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Container started')),
      );
      _tabController.animateTo(2); // Switch to terminal tab
    }
  }

  Future<void> _stopContainer() async {
    if (_selectedProject == null) return;
    await ServerProjectService.stopContainer(_selectedProject!.id);
    setState(() {
      _selectedProject = _selectedProject!.copyWith(
        containerStatus: ContainerStatus.stopped,
      );
    });
  }

  Future<void> _pushProject() async {
    if (_selectedProject == null) return;

    final files = <String, String>{};
    for (final file in _files) {
      if (!file.isDirectory) {
        final content = await ServerProjectService.getFileContent(
          _selectedProject!.id,
          file.path,
        );
        if (content != null) files[file.path] = content;
      }
    }

    final pushed = await ServerProjectService.pushProject(
      projectId: _selectedProject!.id,
      files: files,
      commitMessage: 'Push from SIDE IDE',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pushed ? 'Project pushed to server' : 'Push failed'),
        ),
      );
    }
  }

  void _showNewProjectSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProjectShareScreen()),
    ).then((_) => _loadProjects());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF263238),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF58A6FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud, size: 16, color: Color(0xFF58A6FF)),
            ),
            const SizedBox(width: 10),
            Text(
              _selectedProject?.name ?? 'Server IDE',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_selectedProject != null) ...[
            if (_selectedProject!.isRunning)
              IconButton(
                icon: const Icon(Icons.stop_circle, size: 20),
                onPressed: _stopContainer,
                tooltip: 'Stop Container',
              )
            else
              IconButton(
                icon: _isContainerStarting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle, size: 20),
                onPressed: _isContainerStarting ? null : _startContainer,
                tooltip: 'Start Container',
              ),
            IconButton(
              icon: const Icon(Icons.cloud_upload, size: 20),
              onPressed: _pushProject,
              tooltip: 'Push to Server',
            ),
            IconButton(
              icon: const Icon(Icons.share, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectShareScreen(project: _selectedProject),
                  ),
                ).then((_) => _loadProjects());
              },
              tooltip: 'Project Settings',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: _showNewProjectSheet,
            tooltip: 'New Project',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _selectedProject == null ? _buildProjectList() : _buildIdeView(),
    );
  }

  Widget _buildProjectList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'No server projects yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a project to deploy on a Docker container',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showNewProjectSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Project'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF263238),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        return _buildProjectCard(project);
      },
    );
  }

  Widget _buildProjectCard(ServerProject project) {
    final isRunning = project.isRunning;
    final color = isRunning ? const Color(0xFF3FB950) : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isRunning
            ? Border.all(color: const Color(0xFF3FB950).withOpacity(0.3))
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectProject(project),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isRunning ? Icons.play_arrow : Icons.folder_open,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project.description.isNotEmpty
                              ? project.description
                              : ServerProjectService.getFrameworkLabel(project.framework),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    ServerProjectService.getFrameworkLabel(project.framework),
                    const Color(0xFF58A6FF),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(project.formattedSize, Colors.grey),
                  const SizedBox(width: 8),
                  _buildInfoChip('${project.fileCount} files', Colors.grey),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRunning
                          ? const Color(0xFF3FB950).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isRunning ? 'Running' : 'Stopped',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildIdeView() {
    return Column(
      children: [
        _buildIdeTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFilesTab(),
              _buildEditorTab(),
              _buildTerminalTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIdeTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF58A6FF),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF58A6FF),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.folder, size: 16), text: 'Files'),
          Tab(icon: Icon(Icons.edit, size: 16), text: 'Editor'),
          Tab(icon: Icon(Icons.terminal, size: 16), text: 'Terminal'),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_files.length} files',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder, size: 18),
                onPressed: () => _showNewFileDialog(),
                tooltip: 'New File',
              ),
            ],
          ),
        ),
        Expanded(
          child: _files.isEmpty
              ? const Center(
                  child: Text(
                    'No files yet. Create your first file.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final isSelected = _selectedFile?.path == file.path;
                    return _buildFileTile(file, isSelected);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFileTile(ProjectFile file, bool isSelected) {
    final icon = file.isDirectory
        ? Icons.folder
        : _getFileIcon(file.name);
    final color = file.isDirectory
        ? const Color(0xFFFFB86C)
        : const Color(0xFF58A6FF);

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: color),
      title: Text(
        file.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF58A6FF) : null,
        ),
      ),
      subtitle: Text(
        file.isDirectory ? 'directory' : file.path,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
      ),
      trailing: isSelected
          ? const Icon(Icons.chevron_right, size: 16, color: Color(0xFF58A6FF))
          : null,
      selected: isSelected,
      onTap: () => _selectFile(file),
    );
  }

  IconData _getFileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.py')) return Icons.code;
    if (name.endsWith('.js') || name.endsWith('.ts')) return Icons.javascript;
    if (name.endsWith('.html') || name.endsWith('.css')) return Icons.web;
    if (name.endsWith('.json') || name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    if (name.endsWith('.md')) return Icons.description;
    if (name.endsWith('.lock')) return Icons.lock;
    return Icons.insert_drive_file;
  }

  Widget _buildEditorTab() {
    if (_selectedFile == null || _fileContent == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 48, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text(
              'Select a file to edit',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Icon(_getFileIcon(_selectedFile!.name), size: 16, color: const Color(0xFF58A6FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFile!.path,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              if (_isSaving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.save, size: 18),
                  onPressed: _saveFile,
                  tooltip: 'Save',
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF0D1117),
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: TextEditingController(text: _fileContent),
              onChanged: (value) => _fileContent = value,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                color: Color(0xFFC9D1D9),
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.5,
              ),
              decoration: const InputDecoration(border: InputBorder.none),
              cursorColor: const Color(0xFF58A6FF),
              keyboardType: TextInputType.multiline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerminalTab() {
    if (_selectedProject == null || !_selectedProject!.isRunning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 48, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text(
              'Start the container to use terminal',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isContainerStarting ? null : _startContainer,
              icon: _isContainerStarting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(_isContainerStarting ? 'Starting...' : 'Start Container'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3FB950),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ServerTerminal(projectId: _selectedProject!.id),
    );
  }

  void _showNewFileDialog() {
    String fileName = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New File'),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'filename.ext',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) => fileName = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (fileName.isNotEmpty && _selectedProject != null) {
                await ServerProjectService.createFile(
                  _selectedProject!.id,
                  fileName,
                  '',
                );
                Navigator.pop(context);
                _selectProject(_selectedProject!);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
