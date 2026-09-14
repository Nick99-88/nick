import '../../core/constants.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String topic;
  final String description;
  final String fileUrl;
  final String thumbnailUrl;
  final String docType;
  final String channelId;
  final String channelName;
  final String channelPic;
  final String uploaderId;
  final String institutionId;
  final int likesCount;
  final int dislikesCount;
  final int reportsCount;
  final int viewsCount;
  final String createdAt;
  final bool userLiked;
  final bool userDisliked;
  final bool userReported;
  final bool userSaved;

  final String fileName;
  final String fileExt;
  final int fileSize;
  final String mimeType;

  final String monetizationType;
  final double price;
  final double earnings;
  final bool forceStopped;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.topic,
    this.description = '',
    required this.fileUrl,
    this.thumbnailUrl = '',
    required this.docType,
    required this.channelId,
    required this.channelName,
    required this.channelPic,
    required this.uploaderId,
    required this.institutionId,
    required this.likesCount,
    required this.dislikesCount,
    required this.reportsCount,
    required this.viewsCount,
    required this.createdAt,
    required this.userLiked,
    required this.userDisliked,
    required this.userReported,
    this.userSaved = false,
    this.fileName = '',
    this.fileExt = '',
    this.fileSize = 0,
    this.mimeType = '',
    this.monetizationType = 'free',
    this.price = 0.0,
    this.earnings = 0.0,
    this.forceStopped = false,
  });

  String get absoluteFileUrl {
    if (fileUrl.isEmpty) return fileUrl;
    if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
      return fileUrl;
    }
    return '${StarlightConstants.apiBaseUrl}$fileUrl';
  }

  String get absoluteThumbnailUrl {
    if (thumbnailUrl.isEmpty) return '';
    if (thumbnailUrl.startsWith('http://') || thumbnailUrl.startsWith('https://')) {
      return thumbnailUrl;
    }
    return '${StarlightConstants.apiBaseUrl}$thumbnailUrl';
  }

  String get absoluteChannelPicUrl {
    if (channelPic.isEmpty || channelPic == 'default_avatar') return '';
    if (channelPic.startsWith('http://') || channelPic.startsWith('https://')) {
      return channelPic;
    }
    return '${StarlightConstants.apiBaseUrl}$channelPic';
  }

  /// 🏛️ Lowercase extension without the leading dot (`pdf`, `png`, `docx`).
  /// Falls back to inferring from `file_name` or the URL path so old records
  /// (pre-multipart) keep working.
  String get resolvedExt {
    if (fileExt.isNotEmpty) return fileExt.toLowerCase();
    if (fileName.contains('.')) {
      return fileName.split('.').last.toLowerCase();
    }
    if (fileUrl.contains('.')) {
      final tail = fileUrl.split('?').first.split('/').last;
      if (tail.contains('.')) {
        return tail.split('.').last.toLowerCase();
      }
    }
    return '';
  }

  /// 🏛️ Rough file-type bucket so the UI can pick the right icon / viewer.
  String get fileKind {
    final ext = resolvedExt;
    const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg', 'heic', 'tiff'};
    const docExts = {'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt', 'md'};
    const sheetExts = {'xls', 'xlsx', 'ods', 'csv'};
    const slideExts = {'ppt', 'pptx', 'odp'};
    const audioExts = {'mp3', 'wav', 'm4a', 'aac', 'ogg'};
    const archiveExts = {'zip', 'rar', '7z'};

    if (imageExts.contains(ext)) return 'image';
    if (docExts.contains(ext)) return 'document';
    if (sheetExts.contains(ext)) return 'spreadsheet';
    if (slideExts.contains(ext)) return 'presentation';
    if (audioExts.contains(ext)) return 'audio';
    if (archiveExts.contains(ext)) return 'archive';
    return 'other';
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? 'Unknown',
      topic: json['topic'] ?? 'General',
      description: json['description'] ?? '',
      fileUrl: json['file_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      docType: json['doc_type'] ?? 'book',
      channelId: json['channel_id'] ?? '',
      channelName: json['channel_name'] ?? 'Library Channel',
      channelPic: json['channel_pic'] ?? 'default_avatar',
      uploaderId: json['uploader_id'] ?? '',
      institutionId: json['institution_id'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      dislikesCount: json['dislikes_count'] ?? 0,
      reportsCount: json['reports_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      userLiked: json['user_liked'] == true,
      userDisliked: json['user_disliked'] == true,
      userReported: json['user_reported'] == true,
      userSaved: json['user_saved'] == true,
      fileName: json['file_name'] ?? '',
      fileExt: json['file_ext'] ?? '',
      fileSize: (json['file_size'] is num) ? (json['file_size'] as num).toInt() : 0,
      mimeType: json['mime_type'] ?? '',
      monetizationType: json['monetization_type'] ?? 'free',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      earnings: (json['earnings'] is num) ? (json['earnings'] as num).toDouble() : 0.0,
      forceStopped: json['force_stopped'] == true,
    );
  }

  Book copyWith({
    int? likesCount,
    int? dislikesCount,
    int? reportsCount,
    int? viewsCount,
    bool? userLiked,
    bool? userDisliked,
    bool? userReported,
    bool? userSaved,
    double? earnings,
    bool? forceStopped,
  }) {
    return Book(
      id: id,
      title: title,
      author: author,
      topic: topic,
      description: description,
      fileUrl: fileUrl,
      thumbnailUrl: thumbnailUrl,
      docType: docType,
      channelId: channelId,
      channelName: channelName,
      channelPic: channelPic,
      uploaderId: uploaderId,
      institutionId: institutionId,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      reportsCount: reportsCount ?? this.reportsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt,
      userLiked: userLiked ?? this.userLiked,
      userDisliked: userDisliked ?? this.userDisliked,
      userReported: userReported ?? this.userReported,
      userSaved: userSaved ?? this.userSaved,
      fileName: fileName,
      fileExt: fileExt,
      fileSize: fileSize,
      mimeType: mimeType,
      monetizationType: monetizationType,
      price: price,
      earnings: earnings ?? this.earnings,
      forceStopped: forceStopped ?? this.forceStopped,
    );
  }
}

class LibraryChannel {
  final String id;
  final String name;
  final String description;
  final String profilePic;
  final String ownerId;
  final String ownerName;
  final String createdAt;
  final bool userSubscribed;

  LibraryChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.profilePic,
    required this.ownerId,
    required this.ownerName,
    required this.createdAt,
    this.userSubscribed = false,
  });

  factory LibraryChannel.fromJson(Map<String, dynamic> json) {
    return LibraryChannel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      profilePic: json['profile_pic'] ?? 'default_avatar',
      ownerId: json['owner_id'] ?? '',
      ownerName: json['owner_name'] ?? 'Author',
      createdAt: json['created_at'] ?? '',
      userSubscribed: json['user_subscribed'] == true,
    );
  }

  String get absoluteProfilePicUrl {
    if (profilePic.isEmpty || profilePic == 'default_avatar') return '';
    if (profilePic.startsWith('http://') || profilePic.startsWith('https://')) {
      return profilePic;
    }
    return '${StarlightConstants.apiBaseUrl}$profilePic';
  }

  LibraryChannel copyWith({
    bool? userSubscribed,
  }) {
    return LibraryChannel(
      id: id,
      name: name,
      description: description,
      profilePic: profilePic,
      ownerId: ownerId,
      ownerName: ownerName,
      createdAt: createdAt,
      userSubscribed: userSubscribed ?? this.userSubscribed,
    );
  }
}

class BookComment {
  final String id;
  final String userId;
  final String userName;
  final String commentText;
  final String createdAt;

  // 🏛️ Rich comment features
  final bool isPinned;
  final bool isAuthorComment;
  final int likesCount;
  final int dislikesCount;
  final bool userLiked;
  final bool userDisliked;

  BookComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.commentText,
    required this.createdAt,
    this.isPinned = false,
    this.isAuthorComment = false,
    this.likesCount = 0,
    this.dislikesCount = 0,
    this.userLiked = false,
    this.userDisliked = false,
  });

  factory BookComment.fromJson(Map<String, dynamic> json) {
    return BookComment(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? 'User',
      commentText: json['comment_text'] ?? '',
      createdAt: json['created_at'] ?? '',
      isPinned: json['is_pinned'] == true,
      isAuthorComment: json['is_author_comment'] == true,
      likesCount: json['likes_count'] ?? 0,
      dislikesCount: json['dislikes_count'] ?? 0,
      userLiked: json['user_liked'] == true,
      userDisliked: json['user_disliked'] == true,
    );
  }

  BookComment copyWith({
    bool? isPinned,
    int? likesCount,
    int? dislikesCount,
    bool? userLiked,
    bool? userDisliked,
  }) {
    return BookComment(
      id: id,
      userId: userId,
      userName: userName,
      commentText: commentText,
      createdAt: createdAt,
      isPinned: isPinned ?? this.isPinned,
      isAuthorComment: isAuthorComment,
      likesCount: likesCount ?? this.likesCount,
      dislikesCount: dislikesCount ?? this.dislikesCount,
      userLiked: userLiked ?? this.userLiked,
      userDisliked: userDisliked ?? this.userDisliked,
    );
  }
}

class LibraryPlaylist {
  final String id;
  final String title;
  final String description;
  final String visibility;
  final int itemCount;
  final List<Book>? books;
  final String createdAt;
  final String updatedAt;

  LibraryPlaylist({
    required this.id,
    required this.title,
    this.description = '',
    this.visibility = 'public',
    this.itemCount = 0,
    this.books,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LibraryPlaylist.fromJson(Map<String, dynamic> json) {
    return LibraryPlaylist(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      visibility: json['visibility'] ?? 'public',
      itemCount: json['item_count'] ?? 0,
      books: json['books'] is List
          ? (json['books'] as List).map((b) => Book.fromJson(b)).toList()
          : null,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }
}
