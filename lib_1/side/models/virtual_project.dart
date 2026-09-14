import 'dart:convert';

class VirtualFile {
  String id;
  String name;
  String content;
  bool isPlugin;

  VirtualFile({
    required this.id,
    required this.name,
    required this.content,
    this.isPlugin = false,
  });

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot) : '';
  }

  String get folder {
    final slash = name.lastIndexOf('/');
    return slash >= 0 ? name.substring(0, slash) : '/';
  }

  String get displayName => name.contains('/') ? name.split('/').last : name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'content': content,
        'is_plugin': isPlugin,
      };

  factory VirtualFile.fromJson(Map<String, dynamic> json) => VirtualFile(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        content: json['content'] ?? '',
        isPlugin: json['is_plugin'] ?? json['isPlugin'] ?? false,
      );

  VirtualFile copyWith({String? name, String? content, bool? isPlugin}) => VirtualFile(
        id: id,
        name: name ?? this.name,
        content: content ?? this.content,
        isPlugin: isPlugin ?? this.isPlugin,
      );
}

class VirtualProject {
  final String id;
  final String name;
  String language;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isSynced;
  List<VirtualFile> files;
  List<String> folders;

  VirtualProject({
    required this.id,
    required this.name,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.files = const [],
    this.folders = const [],
  });

  static String defaultEntryFile(String language) {
    switch (language) {
      case 'javascript':
        return 'main.js';
      case 'cpp':
        return 'main.cpp';
      case 'c':
        return 'main.c';
      case 'java':
        return 'Main.java';
      case 'html':
        return 'index.html';
      default:
        return 'main.py';
    }
  }

  factory VirtualProject.create({
    required String name,
    String language = 'python',
    List<VirtualFile>? files,
    List<String>? folders,
  }) {
    final now = DateTime.now();
    final entryName = defaultEntryFile(language);
    return VirtualProject(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      language: language,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
      folders: folders ?? const [],
      files: files ??
          [
            VirtualFile(
              id: '${now.millisecondsSinceEpoch}_main',
              name: entryName,
              content: '',
            ),
          ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'files': files.map((f) => f.toJson()).toList(),
        'folders': folders,
      };

  factory VirtualProject.fromJson(Map<String, dynamic> json) => VirtualProject(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        language: json['language'] ?? 'python',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
        isSynced: json['isSynced'] ?? false,
        files: (json['files'] as List?)
                ?.map((f) => VirtualFile.fromJson(f))
                .toList() ??
            [],
        folders: (json['folders'] as List?)?.cast<String>() ?? [],
      );

  String toJsonString() => jsonEncode(toJson());
}
