class QRLinkModel {
  final String id;
  final String title;
  final String description;
  final String link;
  final String userId;
  final bool isListed;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? scanCount;
  final DateTime? lastScanned;
  final String? contentKey; // 16-character server-generated key

  QRLinkModel({
    required this.id,
    required this.title,
    required this.description,
    required this.link,
    required this.userId,
    this.isListed = true,
    required this.createdAt,
    this.expiresAt,
    this.scanCount = 0,
    this.lastScanned,
    this.contentKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'link': link,
      'user_id': userId,
      'is_listed': isListed,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'scan_count': scanCount,
      'last_scanned': lastScanned?.toIso8601String(),
      'content_key': contentKey,
    };
  }

  factory QRLinkModel.fromJson(Map<String, dynamic> json) {
    return QRLinkModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      link: json['link'] ?? '',
      userId: json['user_id'] ?? '',
      isListed: json['is_listed'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at']) : null,
      scanCount: json['scan_count'] ?? 0,
      lastScanned: json['last_scanned'] != null ? DateTime.parse(json['last_scanned']) : null,
      contentKey: json['content_key'],
    );
  }
}
