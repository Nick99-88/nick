import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';

class VideoNotificationService {
  static String get _baseUrl => StarlightConstants.apiBaseUrl;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await StarlightStorage.getUserToken();
    return {'Authorization': 'Bearer $token'};
  }

  static Future<NotificationPage> getNotifications({bool unreadOnly = false, int limit = 30}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/notifications?unread_only=$unreadOnly&limit=$limit'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return NotificationPage(
        notifications: (data['notifications'] as List)
            .map((e) => VideoNotification.fromJson(e))
            .toList(),
        unreadCount: data['unread_count'] ?? 0,
      );
    }
    throw Exception('Failed to load notifications');
  }

  static Future<int> getUnreadCount() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/api/video/notifications/unread-count'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['unread_count'] ?? 0;
    }
    return 0;
  }

  static Future<void> markAsRead(String notificationId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/notifications/$notificationId/read'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Failed to mark as read');
  }

  static Future<void> markAllAsRead() async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/video/notifications/read-all'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) throw Exception('Failed to mark all as read');
  }
}

class VideoNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String? videoId;
  final String? senderId;
  final String? commentId;
  final bool isRead;
  final String createdAt;

  VideoNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.videoId,
    this.senderId,
    this.commentId,
    required this.isRead,
    required this.createdAt,
  });

  factory VideoNotification.fromJson(Map<String, dynamic> json) {
    return VideoNotification(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      videoId: json['video_id'],
      senderId: json['sender_id'],
      commentId: json['comment_id'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
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

  IconData get icon {
    switch (type) {
      case 'new_subscriber':
        return Icons.person_add;
      case 'new_comment':
        return Icons.comment;
      case 'new_like':
        return Icons.thumb_up;
      case 'video_ready':
        return Icons.check_circle;
      case 'video_failed':
        return Icons.error;
      case 'video_report':
        return Icons.flag;
      default:
        return Icons.notifications;
    }
  }
}

class NotificationPage {
  final List<VideoNotification> notifications;
  final int unreadCount;

  NotificationPage({
    required this.notifications,
    required this.unreadCount,
  });
}
