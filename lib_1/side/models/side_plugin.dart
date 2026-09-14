class SidePlugin {
  final String id;
  final String name;
  final String description;
  final String language;
  final String version;
  final String author;
  final String fileName;
  final String fileContent;
  final String icon;
  final int downloads;
  final String? createdAt;
  final String? updatedAt;

  SidePlugin({
    required this.id,
    required this.name,
    required this.description,
    required this.language,
    required this.version,
    required this.author,
    required this.fileName,
    required this.fileContent,
    required this.icon,
    required this.downloads,
    this.createdAt,
    this.updatedAt,
  });

  factory SidePlugin.fromJson(Map<String, dynamic> json) => SidePlugin(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        language: json['language'] ?? '',
        version: json['version'] ?? '1.0.0',
        author: json['author'] ?? '',
        fileName: json['file_name'] ?? '',
        fileContent: json['file_content'] ?? '',
        icon: json['icon'] ?? 'extension',
        downloads: json['downloads'] ?? 0,
        createdAt: json['created_at'],
        updatedAt: json['updated_at'],
      );
}
