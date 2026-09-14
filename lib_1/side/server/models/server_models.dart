enum ContainerStatus {
  creating,
  running,
  stopped,
  error,
  expired,
}

enum ProjectVisibility {
  private,
  public,
}

class ServerProject {
  final String id;
  final String name;
  final String description;
  final String framework;
  final String ownerPublicId;
  final ProjectVisibility visibility;
  final ContainerStatus containerStatus;
  final String? containerId;
  final String? containerUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAccessedAt;
  final int fileCount;
  final int totalSizeBytes;
  final List<String> tags;
  final int starCount;
  final int forkCount;
  final bool isOwner;

  ServerProject({
    required this.id,
    required this.name,
    required this.description,
    required this.framework,
    required this.ownerPublicId,
    this.visibility = ProjectVisibility.private,
    this.containerStatus = ContainerStatus.stopped,
    this.containerId,
    this.containerUrl,
    required this.createdAt,
    required this.updatedAt,
    this.lastAccessedAt,
    this.fileCount = 0,
    this.totalSizeBytes = 0,
    this.tags = const [],
    this.starCount = 0,
    this.forkCount = 0,
    this.isOwner = false,
  });

  factory ServerProject.fromJson(Map<String, dynamic> json) {
    return ServerProject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      framework: json['framework'] ?? 'python',
      ownerPublicId: json['ownerPublicId'] ?? '',
      visibility: ProjectVisibility.values.firstWhere(
        (v) => v.name == json['visibility'],
        orElse: () => ProjectVisibility.private,
      ),
      containerStatus: ContainerStatus.values.firstWhere(
        (s) => s.name == json['containerStatus'],
        orElse: () => ContainerStatus.stopped,
      ),
      containerId: json['containerId'],
      containerUrl: json['containerUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      lastAccessedAt: json['lastAccessedAt'] != null
          ? DateTime.tryParse(json['lastAccessedAt'])
          : null,
      fileCount: json['fileCount'] ?? 0,
      totalSizeBytes: json['totalSizeBytes'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      starCount: json['starCount'] ?? 0,
      forkCount: json['forkCount'] ?? 0,
      isOwner: json['isOwner'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'framework': framework,
        'ownerPublicId': ownerPublicId,
        'visibility': visibility.name,
        'containerStatus': containerStatus.name,
        'containerId': containerId,
        'containerUrl': containerUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt?.toIso8601String(),
        'fileCount': fileCount,
        'totalSizeBytes': totalSizeBytes,
        'tags': tags,
        'starCount': starCount,
        'forkCount': forkCount,
        'isOwner': isOwner,
      };

  String get formattedSize {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  bool get isRunning => containerStatus == ContainerStatus.running;

  ServerProject copyWith({
    String? name,
    String? description,
    String? framework,
    ProjectVisibility? visibility,
    ContainerStatus? containerStatus,
    String? containerId,
    String? containerUrl,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    int? fileCount,
    int? totalSizeBytes,
    List<String>? tags,
    int? starCount,
    int? forkCount,
  }) {
    return ServerProject(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      framework: framework ?? this.framework,
      ownerPublicId: ownerPublicId,
      visibility: visibility ?? this.visibility,
      containerStatus: containerStatus ?? this.containerStatus,
      containerId: containerId ?? this.containerId,
      containerUrl: containerUrl ?? this.containerUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      fileCount: fileCount ?? this.fileCount,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      tags: tags ?? this.tags,
      starCount: starCount ?? this.starCount,
      forkCount: forkCount ?? this.forkCount,
      isOwner: isOwner,
    );
  }
}

class ProjectFile {
  final String path;
  final String name;
  final String? content;
  final int sizeBytes;
  final DateTime updatedAt;
  final bool isDirectory;

  ProjectFile({
    required this.path,
    required this.name,
    this.content,
    this.sizeBytes = 0,
    required this.updatedAt,
    this.isDirectory = false,
  });

  factory ProjectFile.fromJson(Map<String, dynamic> json) {
    return ProjectFile(
      path: json['path'] ?? '',
      name: json['name'] ?? '',
      content: json['content'],
      sizeBytes: json['sizeBytes'] ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      isDirectory: json['isDirectory'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'content': content,
        'sizeBytes': sizeBytes,
        'updatedAt': updatedAt.toIso8601String(),
        'isDirectory': isDirectory,
      };
}

class TerminalLog {
  final String stream;
  final String message;
  final DateTime timestamp;

  TerminalLog({
    required this.stream,
    required this.message,
    required this.timestamp,
  });

  factory TerminalLog.fromJson(Map<String, dynamic> json) {
    return TerminalLog(
      stream: json['stream'] ?? 'stdout',
      message: json['message'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isError => stream == 'stderr';
}

class ContainerConfig {
  final String framework;
  final String? dockerImage;
  final int? port;
  final Map<String, String>? envVars;
  final int? memoryLimitMb;
  final int? cpuLimitPercent;
  final Duration? maxRuntime;

  ContainerConfig({
    required this.framework,
    this.dockerImage,
    this.port,
    this.envVars,
    this.memoryLimitMb,
    this.cpuLimitPercent,
    this.maxRuntime,
  });

  static const Map<String, String> defaultImages = {
    'python': 'python:3.12-slim',
    'fastapi': 'python:3.12-slim',
    'flask': 'python:3.12-slim',
    'django': 'python:3.12-slim',
    'node': 'node:20-slim',
    'express': 'node:20-slim',
    'nextjs': 'node:20-alpine',
    'flutter': 'ghcr.io/cirruslabs/flutter:stable',
    'java': 'eclipse-temurin:21-jdk',
    'spring': 'eclipse-temurin:21-jdk',
    'go': 'golang:1.22-alpine',
    'rust': 'rust:slim',
    'cpp': 'gcc:13',
  };

  static const Map<String, int> defaultPorts = {
    'python': 8000,
    'fastapi': 8000,
    'flask': 5000,
    'django': 8000,
    'node': 3000,
    'express': 3000,
    'nextjs': 3000,
    'flutter': 8080,
    'java': 8080,
    'spring': 8080,
    'go': 8080,
    'rust': 8080,
    'cpp': 8080,
  };

  String get effectiveDockerImage => dockerImage ?? defaultImages[framework] ?? 'ubuntu:22.04';
  int get effectivePort => port ?? defaultPorts[framework] ?? 8080;

  Map<String, dynamic> toJson() => {
        'framework': framework,
        'dockerImage': effectiveDockerImage,
        'port': effectivePort,
        'envVars': envVars,
        'memoryLimitMb': memoryLimitMb ?? 512,
        'cpuLimitPercent': cpuLimitPercent ?? 50,
        'maxRuntimeMinutes': maxRuntime?.inMinutes ?? 60,
      };
}
