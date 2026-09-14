import 'dart:convert';

class VideoPost {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String uploaderId;
  final String uploaderName;
  final String? uploaderAvatar;
  final String category;
  final List<String> tags;
  final int views;
  final int likes;
  final int dislikes;
  final bool isLiked;
  final bool isDisliked;
  final bool isSubscribed;
  final int commentCount;
  final String visibility;
  final String createdAt;
  final double duration;
  final String? status;
  final int? progress;
  final bool? audioReady;
  final String? audioOnlyUrl;
  final int? retryAttempt;
  final int? retryCount;

  VideoPost({
    required this.id,
    required this.title,
    this.description = '',
    required this.videoUrl,
    this.thumbnailUrl = '',
    required this.uploaderId,
    this.uploaderName = '',
    this.uploaderAvatar,
    this.category = 'general',
    this.tags = const [],
    this.views = 0,
    this.likes = 0,
    this.dislikes = 0,
    this.isLiked = false,
    this.isDisliked = false,
    this.isSubscribed = false,
    this.commentCount = 0,
    this.visibility = 'public',
    required this.createdAt,
    this.duration = 0,
    this.status,
    this.progress,
    this.audioReady,
    this.audioOnlyUrl,
    this.retryAttempt,
    this.retryCount,
  });

  factory VideoPost.fromJson(Map<String, dynamic> json) {
    return VideoPost(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      videoUrl: json['video_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      uploaderId: json['uploader_id']?.toString() ?? '',
      uploaderName: json['uploader_name']?.toString() ?? '',
      uploaderAvatar: json['uploader_avatar']?.toString(),
      category: json['category']?.toString() ?? 'general',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      dislikes: json['dislikes'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isDisliked: json['is_disliked'] ?? false,
      isSubscribed: json['is_subscribed'] ?? false,
      commentCount: json['comment_count'] ?? 0,
      visibility: json['visibility'] is bool
          ? (json['visibility'] ? 'public' : 'private')
          : (json['visibility']?.toString() ?? 'public'),
      createdAt: json['created_at']?.toString() ?? '',
      duration: (json['duration'] ?? 0).toDouble(),
      status: json['status']?.toString(),
      progress: json['progress'],
      audioReady: json['audio_ready'],
      audioOnlyUrl: json['audio_only_url']?.toString(),
      retryAttempt: json['retry_attempt'],
      retryCount: json['retry_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'uploader_id': uploaderId,
      'uploader_name': uploaderName,
      'uploader_avatar': uploaderAvatar,
      'category': category,
      'tags': tags,
      'views': views,
      'likes': likes,
      'dislikes': dislikes,
      'is_liked': isLiked,
      'is_disliked': isDisliked,
      'is_subscribed': isSubscribed,
      'comment_count': commentCount,
      'visibility': visibility,
      'created_at': createdAt,
      'duration': duration,
      'status': status,
      'progress': progress,
      'audio_ready': audioReady,
      'audio_only_url': audioOnlyUrl,
      'retry_attempt': retryAttempt,
      'retry_count': retryCount,
    };
  }

  String get formattedDuration {
    if (duration <= 0) return '';
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration.toInt() % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get viewsFormatted {
    if (views >= 1000000) return '${(views / 1000000).toStringAsFixed(1)}M';
    if (views >= 1000) return '${(views / 1000).toStringAsFixed(1)}K';
    return views.toString();
  }
}

class VideoComment {
  final String id;
  final String videoId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String text;
  final int likes;
  final bool isLiked;
  final bool isDisliked;
  final bool isOwner;
  final String createdAt;
  final List<VideoComment> replies;
  final int replyCount;

  VideoComment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.text,
    this.likes = 0,
    this.isLiked = false,
    this.isDisliked = false,
    this.isOwner = false,
    required this.createdAt,
    this.replies = const [],
    this.replyCount = 0,
  });

  factory VideoComment.fromJson(Map<String, dynamic> json) {
    final repliesList = (json['replies'] as List<dynamic>?)
            ?.map((e) => VideoComment.fromJson(e))
            .toList() ??
        [];
    return VideoComment(
      id: json['id'] ?? '',
      videoId: json['video_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'] ?? '',
      userAvatar: json['user_avatar'],
      text: json['text'] ?? '',
      likes: json['likes'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isDisliked: json['is_disliked'] ?? false,
      isOwner: json['is_owner'] ?? false,
      createdAt: json['created_at'] ?? '',
      replies: repliesList,
      replyCount: json['reply_count'] ?? repliesList.length,
    );
  }

  String get timeAgo {
    try {
      final date = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(date);
      final abs = diff.isNegative ? -diff : diff;
      if (abs.inDays > 365) return '${(abs.inDays ~/ 365)}y ago';
      if (abs.inDays > 30) return '${(abs.inDays ~/ 30)}mo ago';
      if (abs.inDays > 0) return '${abs.inDays}d ago';
      if (abs.inHours > 0) return '${abs.inHours}h ago';
      if (abs.inMinutes > 0) return '${abs.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }
}

class Channel {
  final String id;
  final String name;
  final String? avatar;
  final String? banner;
  final String? description;
  final int subscriberCount;
  final bool isSubscribed;
  final int videoCount;
  final bool hasChannel;
  final bool isOwner;
  final List<Map<String, String>> links;
  final String? createdAt;
  final int totalViews;

  Channel({
    required this.id,
    required this.name,
    this.avatar,
    this.banner,
    this.description,
    this.subscriberCount = 0,
    this.isSubscribed = false,
    this.videoCount = 0,
    this.hasChannel = false,
    this.isOwner = false,
    this.links = const [],
    this.createdAt,
    this.totalViews = 0,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    List<Map<String, String>> parsedLinks = [];
    final linksRaw = json['links'];
    if (linksRaw is String && linksRaw.isNotEmpty) {
      try {
        final list = jsonDecode(linksRaw) as List;
        parsedLinks = list.map((e) => Map<String, String>.from(e)).toList();
      } catch (_) {}
    }
    return Channel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      banner: json['banner']?.toString(),
      description: json['description']?.toString(),
      subscriberCount: json['subscriber_count'] ?? 0,
      isSubscribed: json['is_subscribed'] ?? false,
      videoCount: json['video_count'] ?? 0,
      hasChannel: json['has_channel'] ?? false,
      isOwner: json['is_owner'] ?? false,
      links: parsedLinks,
      createdAt: json['created_at']?.toString(),
      totalViews: json['total_views'] ?? 0,
    );
  }
}

class Playlist {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final int videoCount;
  final String createdAt;
  final String updatedAt;

  Playlist({
    required this.id,
    required this.title,
    this.thumbnailUrl,
    this.videoCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      videoCount: json['video_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thumbnail_url': thumbnailUrl,
      'video_count': videoCount,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
