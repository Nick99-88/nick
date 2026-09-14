import 'dart:convert';

class CodeProject {
  final String id;
  final String name;
  final String language;
  final String code;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isCloudSynced;
  final Map<String, String> files;

  CodeProject({
    required this.id,
    required this.name,
    required this.language,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
    this.isCloudSynced = false,
    this.files = const {},
  });

  factory CodeProject.create({
    required String name,
    required String language,
    String code = '',
  }) {
    return CodeProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      language: language,
      code: code,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  CodeProject copyWith({
    String? name,
    String? language,
    String? code,
    DateTime? updatedAt,
    bool? isCloudSynced,
    Map<String, String>? files,
  }) {
    return CodeProject(
      id: id,
      name: name ?? this.name,
      language: language ?? this.language,
      code: code ?? this.code,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isCloudSynced: isCloudSynced ?? this.isCloudSynced,
      files: files ?? this.files,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'code': code,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isCloudSynced': isCloudSynced,
        'files': files,
      };

  factory CodeProject.fromJson(Map<String, dynamic> json) {
    return CodeProject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      language: json['language'] ?? 'python',
      code: json['code'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      isCloudSynced: json['isCloudSynced'] ?? false,
      files: Map<String, String>.from(json['files'] ?? {}),
    );
  }

  String toJsonString() => jsonEncode(toJson());
}
