class MediaInfo {
  final int? id;
  final int messageId;
  final String filePath;
  final String fileType;
  final int fileSizeBytes;
  final bool isDownloaded;
  final double downloadProgress;
  final String lastAccessed;

  const MediaInfo({
    this.id,
    required this.messageId,
    required this.filePath,
    required this.fileType,
    required this.fileSizeBytes,
    this.isDownloaded = false,
    this.downloadProgress = 0.0,
    this.lastAccessed = '',
  });

  factory MediaInfo.fromMap(Map<String, dynamic> map) {
    return MediaInfo(
      id: map['id'] as int?,
      messageId: map['message_id'] as int,
      filePath: map['file_path'] as String,
      fileType: map['file_type'] as String,
      fileSizeBytes: map['file_size_bytes'] as int,
      isDownloaded: (map['is_downloaded'] as int? ?? 0) == 1,
      downloadProgress: map['download_progress'] as double? ?? 0.0,
      lastAccessed: map['last_accessed'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'message_id': messageId,
      'file_path': filePath,
      'file_type': fileType,
      'file_size_bytes': fileSizeBytes,
      'is_downloaded': isDownloaded ? 1 : 0,
      'download_progress': downloadProgress,
      'last_accessed': lastAccessed,
    };
  }

  MediaInfo copyWith({
    int? id,
    int? messageId,
    String? filePath,
    String? fileType,
    int? fileSizeBytes,
    bool? isDownloaded,
    double? downloadProgress,
    String? lastAccessed,
  }) {
    return MediaInfo(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    if (fileSizeBytes < 1024 * 1024 * 1024) return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool get isImage => fileType == 'image';
  bool get isVideo => fileType == 'video';
  bool get isAudio => fileType == 'audio';
  bool get isDocument => fileType == 'document';

  @override
  String toString() => 'MediaInfo(id: $id, filePath: $filePath, type: $fileType, size: $formattedSize)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
