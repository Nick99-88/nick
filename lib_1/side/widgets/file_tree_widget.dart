import 'package:flutter/material.dart';
import '../models/virtual_project.dart';
import '../theme/editor_theme.dart';

class SideFileTree extends StatefulWidget {
  final VirtualProject project;
  final String? selectedFileId;
  final ValueChanged<VirtualFile> onFileSelected;
  final VoidCallback onFilesChanged;
  final VoidCallback onExport;
  final VoidCallback? onImport;

  const SideFileTree({
    super.key,
    required this.project,
    this.selectedFileId,
    required this.onFileSelected,
    required this.onFilesChanged,
    required this.onExport,
    this.onImport,
  });

  @override
  State<SideFileTree> createState() => _SideFileTreeState();
}

class _SideFileTreeState extends State<SideFileTree> {
  final Set<String> _expandedFolders = {'/'};

  String _boilerplate(String name) {
    final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')).toLowerCase() : '';
    switch (ext) {
      case '.html':
        return '<html>\n<head>\n  <title></title>\n</head>\n<body>\n  \n</body>\n</html>';
      case '.c':
        return '#include <stdio.h>\n#include <stdlib.h>\n\nint main() {\n    \n    return 0;\n}\n';
      case '.cpp':
        return '#include <iostream>\nusing namespace std;\n\nint main() {\n    \n    return 0;\n}\n';
      case '.h':
        return '#ifndef _HEADER_\n#define _HEADER_\n\n#endif\n';
      case '.js':
        return '';
      case '.py':
        return '';
      default:
        return '';
    }
  }

  Map<String, List<VirtualFile>> get _groupedFiles {
    final map = <String, List<VirtualFile>>{};
    for (final folder in widget.project.folders) {
      map.putIfAbsent(folder, () => []);
    }
    for (final file in widget.project.files) {
      final folder = file.folder;
      map.putIfAbsent(folder, () => []).add(file);
    }
    return map;
  }

  List<String> get _folders {
    final folders = _groupedFiles.keys.toList()..sort();
    return folders;
  }

  void _showNewFileDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SideEditorTheme.surfaceDark,
        title: const Text('New File', style: TextStyle(color: SideEditorTheme.textDark)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SideEditorTheme.textDark, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'filename.dart  (full name)',
            hintStyle: const TextStyle(color: SideEditorTheme.lineNumberColor),
            filled: true,
            fillColor: SideEditorTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SideEditorTheme.lineNumberColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final now = DateTime.now().millisecondsSinceEpoch;
                final file = VirtualFile(
                  id: '${now}_${name}',
                  name: name,
                  content: _boilerplate(name),
                );
                widget.project.files = [...widget.project.files, file];
                widget.onFilesChanged();
                widget.onFileSelected(file);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: SideEditorTheme.accentGreen),
            child: const Text('Create', style: TextStyle(color: SideEditorTheme.backgroundDark)),
          ),
        ],
      ),
    );
  }

  void _showNewFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SideEditorTheme.surfaceDark,
        title: const Text('New Folder', style: TextStyle(color: SideEditorTheme.textDark)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SideEditorTheme.textDark, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'folder name',
            hintStyle: const TextStyle(color: SideEditorTheme.lineNumberColor),
            filled: true,
            fillColor: SideEditorTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SideEditorTheme.lineNumberColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final folderPath = '/$name';
                setState(() {
                  widget.project.folders = [...widget.project.folders, folderPath];
                  _expandedFolders.add(folderPath);
                });
                widget.onFilesChanged();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: SideEditorTheme.accentGreen),
            child: const Text('Create', style: TextStyle(color: SideEditorTheme.backgroundDark)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(VirtualFile file) {
    final controller = TextEditingController(text: file.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SideEditorTheme.surfaceDark,
        title: const Text('Rename File', style: TextStyle(color: SideEditorTheme.textDark)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SideEditorTheme.textDark, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'new name',
            hintStyle: const TextStyle(color: SideEditorTheme.lineNumberColor),
            filled: true,
            fillColor: SideEditorTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SideEditorTheme.lineNumberColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  final idx = widget.project.files.indexWhere((f) => f.id == file.id);
                  if (idx >= 0) {
                    widget.project.files[idx] = file.copyWith(name: newName);
                  }
                });
                widget.onFilesChanged();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: SideEditorTheme.accentGreen),
            child: const Text('Rename', style: TextStyle(color: SideEditorTheme.backgroundDark)),
          ),
        ],
      ),
    );
  }

  void _deleteFile(VirtualFile file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SideEditorTheme.surfaceDark,
        title: const Text('Delete File', style: TextStyle(color: SideEditorTheme.textDark)),
        content: Text('Delete "${file.displayName}"?',
            style: const TextStyle(color: SideEditorTheme.textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SideEditorTheme.lineNumberColor)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                widget.project.files.removeWhere((f) => f.id == file.id);
              });
              widget.onFilesChanged();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: SideEditorTheme.errorRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildFileList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SideEditorTheme.surfaceDark,
        border: Border(bottom: BorderSide(color: SideEditorTheme.lineNumberColor.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Text(widget.project.name,
            style: const TextStyle(
              color: SideEditorTheme.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          _iconButton(Icons.add, 'New file', _showNewFileDialog),
          const SizedBox(width: 4),
          _iconButton(Icons.create_new_folder_outlined, 'New folder', _showNewFolderDialog),
          const SizedBox(width: 4),
          _iconButton(Icons.file_upload_outlined, 'Export', widget.onExport),
          const SizedBox(width: 4),
          if (widget.onImport != null)
            _iconButton(Icons.file_download_outlined, 'Import', widget.onImport!),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: SideEditorTheme.textDark),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    if (_folders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_outlined, size: 32, color: SideEditorTheme.lineNumberColor),
            const SizedBox(height: 8),
            Text('No files yet', style: TextStyle(color: SideEditorTheme.lineNumberColor)),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _showNewFileDialog,
              icon: const Icon(Icons.add, size: 14, color: SideEditorTheme.accentGreen),
              label: const Text('Create one', style: TextStyle(color: SideEditorTheme.accentGreen, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final folder in _folders)
          if (folder == '/')
            DragTarget<String>(
              onAcceptWithDetails: (details) => _moveFileTo(details.data, '/'),
              builder: (ctx, candidates, rejected) => Container(
                decoration: BoxDecoration(
                  color: candidates.isNotEmpty ? const Color(0xFF50FA7B).withOpacity(0.05) : null,
                ),
                child: Column(
                  children: _groupedFiles['/']!.map((f) => _buildFileTile(f)).toList(),
                ),
              ),
            )
          else
            _buildFolderTile(folder),
      ],
    );
  }

  Widget _buildFolderTile(String folder) {
    final isExpanded = _expandedFolders.contains(folder);
    final folderName = folder.split('/').last;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DragTarget<String>(
          onAcceptWithDetails: (details) => _moveFileTo(details.data, folder),
          builder: (ctx, candidates, rejected) => Container(
            decoration: BoxDecoration(
              color: candidates.isNotEmpty ? const Color(0xFF50FA7B).withOpacity(0.05) : null,
            ),
            child: InkWell(
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedFolders.remove(folder);
                } else {
                  _expandedFolders.add(folder);
                }
              }),
              onLongPress: () => _showFolderContextMenu(folder),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                      size: 14, color: SideEditorTheme.lineNumberColor,
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.folder_outlined, size: 14, color: SideEditorTheme.accentYellow),
                    const SizedBox(width: 6),
                    Text(folderName,
                      style: const TextStyle(
                        color: SideEditorTheme.textDark,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (candidates.isNotEmpty)
                      const Text('drop', style: TextStyle(color: Color(0xFF50FA7B), fontSize: 9, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isExpanded)
          DragTarget<String>(
            onAcceptWithDetails: (details) => _moveFileTo(details.data, folder),
            builder: (ctx, candidates, rejected) => Container(
              decoration: BoxDecoration(
                color: candidates.isNotEmpty ? const Color(0xFF50FA7B).withOpacity(0.05) : null,
              ),
              child: Column(
                children: _groupedFiles[folder]!.map((f) => Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: _buildFileTile(f),
                )).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileTile(VirtualFile file) {
    final isSelected = file.id == widget.selectedFileId;
    return Draggable<String>(
      data: file.id,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF282A36),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconForFile(file), size: 12, color: _colorForFile(file)),
              const SizedBox(width: 6),
              Text(file.displayName,
                style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 11, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _fileTileContent(file, isSelected),
      ),
      child: _fileTileContent(file, isSelected),
    );
  }

  Widget _fileTileContent(VirtualFile file, bool isSelected) {
    return InkWell(
      onTap: file.isPlugin ? null : () => widget.onFileSelected(file),
      onLongPress: file.isPlugin ? null : () => _showFileContextMenu(file),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? SideEditorTheme.accentGreen.withOpacity(0.1) : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? SideEditorTheme.accentGreen : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(file.isPlugin ? Icons.lock_outline : _iconForFile(file), size: 14,
                color: file.isPlugin ? SideEditorTheme.lineNumberColor : _colorForFile(file)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.displayName,
                style: TextStyle(
                  color: file.isPlugin ? SideEditorTheme.lineNumberColor : (isSelected ? SideEditorTheme.accentGreen : SideEditorTheme.textDark),
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontStyle: file.isPlugin ? FontStyle.italic : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (file.isPlugin)
              Tooltip(
                message: 'Plugin file - not editable',
                child: Icon(Icons.extension, size: 12, color: SideEditorTheme.lineNumberColor),
              ),
          ],
        ),
      ),
    );
  }

  void _showFolderContextMenu(String folder) {
    final folderName = folder.split('/').last;
    showModalBottomSheet(
      context: context,
      backgroundColor: SideEditorTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(folderName,
                style: const TextStyle(color: SideEditorTheme.textDark, fontFamily: 'monospace')),
            ),
            const Divider(color: SideEditorTheme.lineNumberColor),
            ListTile(
              leading: const Icon(Icons.edit, color: SideEditorTheme.accentGreen),
              title: const Text('Rename', style: TextStyle(color: SideEditorTheme.textDark)),
              onTap: () { Navigator.pop(ctx); _showFolderRenameDialog(folder); },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: SideEditorTheme.accentCyan),
              title: const Text('Duplicate', style: TextStyle(color: SideEditorTheme.textDark)),
              onTap: () { Navigator.pop(ctx); _duplicateFolder(folder); },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: SideEditorTheme.errorRed),
              title: const Text('Delete', style: TextStyle(color: SideEditorTheme.textDark)),
              onTap: () { Navigator.pop(ctx); _deleteFolder(folder); },
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderRenameDialog(String folder) {
    final folderName = folder.split('/').last;
    final controller = TextEditingController(text: folderName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SideEditorTheme.surfaceDark,
        title: const Text('Rename Folder', style: TextStyle(color: SideEditorTheme.textDark)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: SideEditorTheme.textDark, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'new name',
            hintStyle: const TextStyle(color: SideEditorTheme.lineNumberColor),
            filled: true,
            fillColor: SideEditorTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SideEditorTheme.lineNumberColor)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != folderName) {
                setState(() {
                  final parent = folder.contains('/')
                      ? folder.substring(0, folder.lastIndexOf('/'))
                      : '';
                  final newFolder = parent.isEmpty ? '/$newName' : '$parent/$newName';
                  final prefix = folder == '/' ? '' : '$folder/';
                  final newPrefix = newFolder == '/' ? '' : '$newFolder/';
                  for (var i = 0; i < widget.project.files.length; i++) {
                    final f = widget.project.files[i];
                    if (f.name.startsWith(prefix)) {
                      final rest = f.name.substring(prefix.length);
                      widget.project.files[i] = f.copyWith(name: '$newPrefix$rest');
                    }
                  }
                  final idx = widget.project.folders.indexOf(folder);
                  if (idx >= 0) {
                    widget.project.folders[idx] = newFolder;
                  }
                  if (_expandedFolders.contains(folder)) {
                    _expandedFolders.remove(folder);
                    _expandedFolders.add(newFolder);
                  }
                });
                widget.onFilesChanged();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: SideEditorTheme.accentGreen),
            child: const Text('Rename', style: TextStyle(color: SideEditorTheme.backgroundDark)),
          ),
        ],
      ),
    );
  }

  void _duplicateFolder(String folder) {
    final folderName = folder.split('/').last;
    final newFolder = folder.replaceFirst(folderName, '${folderName}_copy');
    setState(() {
      widget.project.folders = [...widget.project.folders, newFolder];
      final prefix = folder == '/' ? '' : '$folder/';
      final newPrefix = newFolder == '/' ? '' : '$newFolder/';
      for (final f in widget.project.files) {
        if (f.name.startsWith(prefix)) {
          final rest = f.name.substring(prefix.length);
          final now = DateTime.now().millisecondsSinceEpoch;
          widget.project.files = [
            ...widget.project.files,
            VirtualFile(id: '${now}_${f.id}', name: '$newPrefix$rest', content: f.content),
          ];
        }
      }
    });
    widget.onFilesChanged();
  }

  void _deleteFolder(String folder) {
    final folderName = folder.split('/').last;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SideEditorTheme.surfaceDark,
        title: const Text('Delete Folder', style: TextStyle(color: SideEditorTheme.textDark)),
        content: Text('Delete folder "$folderName" and all its files?',
            style: const TextStyle(color: SideEditorTheme.textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: SideEditorTheme.lineNumberColor)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                widget.project.folders.remove(folder);
                final prefix = folder == '/' ? '' : '$folder/';
                widget.project.files.removeWhere((f) => f.name.startsWith(prefix));
                _expandedFolders.remove(folder);
              });
              widget.onFilesChanged();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: SideEditorTheme.errorRed),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _moveFileTo(String fileId, String targetFolder) {
    final idx = widget.project.files.indexWhere((f) => f.id == fileId);
    if (idx < 0) return;
    final file = widget.project.files[idx];
    final newName = targetFolder == '/' ? file.displayName : '$targetFolder/${file.displayName}';
    if (file.name == newName) return;
    setState(() {
      widget.project.files[idx] = file.copyWith(name: newName);
    });
    widget.onFilesChanged();
  }

  void _showFileContextMenu(VirtualFile file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SideEditorTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(file.displayName,
                style: const TextStyle(color: SideEditorTheme.textDark, fontFamily: 'monospace')),
            ),
            const Divider(color: SideEditorTheme.lineNumberColor),
            ListTile(
              leading: const Icon(Icons.edit, color: SideEditorTheme.accentGreen),
              title: const Text('Rename', style: TextStyle(color: SideEditorTheme.textDark)),
              onTap: () { Navigator.pop(ctx); _showRenameDialog(file); },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: SideEditorTheme.accentCyan),
              title: const Text('Duplicate', style: TextStyle(color: SideEditorTheme.textDark)),
              onTap: () {
                final now = DateTime.now().millisecondsSinceEpoch;
                final dup = VirtualFile(
                  id: '${now}_copy',
                  name: 'copy_of_${file.name}',
                  content: file.content,
                );
                setState(() {
                  widget.project.files = [...widget.project.files, dup];
                });
                widget.onFilesChanged();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: SideEditorTheme.errorRed),
              title: const Text('Delete', style: TextStyle(color: SideEditorTheme.textDark)),
              onTap: () { Navigator.pop(ctx); _deleteFile(file); },
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForFile(VirtualFile file) {
    final ext = file.extension.toLowerCase();
    switch (ext) {
      case '.dart': return Icons.flutter_dash;
      case '.py': return Icons.code;
      case '.js':
      case '.jsx':
      case '.ts':
      case '.tsx': return Icons.javascript;
      case '.java': return Icons.coffee;
      case '.cpp':
      case '.c':
      case '.h':
      case '.hpp': return Icons.terminal;
      case '.html': return Icons.html;
      case '.css': return Icons.css;
      case '.json': return Icons.data_object;
      case '.yaml':
      case '.yml': return Icons.settings;
      case '.md': return Icons.article;
      default: return Icons.insert_drive_file;
    }
  }

  Color _colorForFile(VirtualFile file) {
    final ext = file.extension.toLowerCase();
    switch (ext) {
      case '.dart': return const Color(0xFF0175C2);
      case '.py': return const Color(0xFFFFD43B);
      case '.js':
      case '.jsx': return const Color(0xFFF7DF1E);
      case '.ts':
      case '.tsx': return const Color(0xFF3178C6);
      case '.java': return const Color(0xFFED8B00);
      case '.cpp':
      case '.c': return const Color(0xFF00599C);
      case '.html': return const Color(0xFFE34F26);
      case '.css': return const Color(0xFF1572B6);
      case '.json': return const Color(0xFF292929);
      case '.md': return const Color(0xFF083FA1);
      default: return SideEditorTheme.lineNumberColor;
    }
  }
}
