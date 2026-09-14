class ProfessionalContentModel {
  final String id;
  final String title;
  final String description;
  final String contentType; // 'text', 'image', 'video', 'document', 'link'
  final String content; // JSON content based on type
  final String userId;
  final bool isListed;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? publishAt;
  final int? viewCount;
  final DateTime? lastViewed;
  final Map<String, dynamic>? metadata;
  final String? qrCodeData; // Base64 encoded QR code image
  final String? qrCodeUrl; // QR code URL for scanning
  final String? contentKey; // 16-character server-generated key

  ProfessionalContentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.contentType,
    required this.content,
    required this.userId,
    this.isListed = true,
    required this.createdAt,
    this.expiresAt,
    this.publishAt,
    this.viewCount = 0,
    this.lastViewed,
    this.metadata,
    this.qrCodeData,
    this.qrCodeUrl,
    this.contentKey,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'content_type': contentType,
      'content_data': content,
      'user_id': userId,
      'is_listed': isListed,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'publish_at': publishAt?.toIso8601String(),
      'view_count': viewCount,
      'last_viewed': lastViewed?.toIso8601String(),
      'metadata': metadata,
      'qr_code_data': qrCodeData,
      'qr_code_url': qrCodeUrl,
      'content_key': contentKey,
    };
  }

  factory ProfessionalContentModel.fromJson(Map<String, dynamic> json) {
    try {
      print('🏛️ ProfessionalContentModel: Starting JSON parsing');
      print('🏛️ ProfessionalContentModel: Raw JSON keys: ${json.keys.toList()}');
      print('🏛️ ProfessionalContentModel: Title field: ${json['title']} (type: ${json['title'].runtimeType})');
      print('🏛️ ProfessionalContentModel: Description field: ${json['description']} (type: ${json['description'].runtimeType})');
      print('🏛️ ProfessionalContentModel: Content type field: ${json['content_type']} (type: ${json['content_type'].runtimeType})');
      
      // Parse content field - API returns content_data, fallback to content
      String rawContent = json['content_data'] ?? json['content'] ?? '';
      if (rawContent == '{}' || rawContent == '""') {
        rawContent = '';
      }
      print('🏛️ ProfessionalContentModel: Content field: "$rawContent"');
      print('🏛️ ProfessionalContentModel: Content Key field: ${json['content_key']} (type: ${json['content_key'].runtimeType})');
      
      // Safe datetime parsing
      DateTime? createdAt;
      if (json['created_at'] != null) {
        if (json['created_at'] is String) {
          createdAt = DateTime.parse(json['created_at']);
        } else if (json['created_at'] is DateTime) {
          createdAt = json['created_at'];
        } else {
          createdAt = DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }
      
      DateTime? expiresAt;
      if (json['expires_at'] != null) {
        if (json['expires_at'] is String) {
          expiresAt = DateTime.parse(json['expires_at']);
        } else if (json['expires_at'] is DateTime) {
          expiresAt = json['expires_at'];
        }
      }

      DateTime? publishAt;
      if (json['publish_at'] != null) {
        if (json['publish_at'] is String) {
          publishAt = DateTime.parse(json['publish_at']);
        } else if (json['publish_at'] is DateTime) {
          publishAt = json['publish_at'];
        }
      }
      
      DateTime? lastViewed;
      if (json['last_viewed'] != null) {
        if (json['last_viewed'] is String) {
          lastViewed = DateTime.parse(json['last_viewed']);
        } else if (json['last_viewed'] is DateTime) {
          lastViewed = json['last_viewed'];
        }
      }
      
      final model = ProfessionalContentModel(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        contentType: json['content_type'] ?? 'text',
        content: rawContent,
        userId: json['user_id'] ?? '',
        isListed: json['is_listed'] ?? true,
        createdAt: createdAt!,
        expiresAt: expiresAt,
        publishAt: publishAt,
        viewCount: json['view_count'] ?? 0,
        lastViewed: lastViewed,
        metadata: json['metadata'] ?? {},
        qrCodeData: json['qr_code_data'],
        qrCodeUrl: json['qr_code_url'],
        contentKey: json['content_key'],
      );
      
      print('🏛️ ProfessionalContentModel: Created model with:');
      print('🏛️ ProfessionalContentModel: - Title: "${model.title}"');
      print('🏛️ ProfessionalContentModel: - Description: "${model.description}"');
      print('🏛️ ProfessionalContentModel: - Content Type: "${model.contentType}"');
      print('🏛️ ProfessionalContentModel: - Content: "${model.content}"');
      print('🏛️ ProfessionalContentModel: - Content Key: "${model.contentKey}"');
      
      return model;
    } catch (e) {
      print('🏛️ ProfessionalContentModel: Error parsing JSON - $e');
      print('🏛️ ProfessionalContentModel: JSON data - $json');
      rethrow;
    }
  }
}
