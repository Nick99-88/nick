import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../services/video_notification_service.dart';
import 'video_player_screen.dart';
import '../models/video_models.dart';
import '../services/video_service.dart';

class VideoNotificationsScreen extends StatefulWidget {
  const VideoNotificationsScreen({super.key});

  @override
  State<VideoNotificationsScreen> createState() => _VideoNotificationsScreenState();
}

class _VideoNotificationsScreenState extends State<VideoNotificationsScreen> {
  List<VideoNotification> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final page = await VideoNotificationService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = page.notifications;
          _unreadCount = page.unreadCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await VideoNotificationService.markAsRead(id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == id);
        if (idx != -1) {
          _notifications[idx] = VideoNotification(
            id: _notifications[idx].id,
            userId: _notifications[idx].userId,
            type: _notifications[idx].type,
            title: _notifications[idx].title,
            message: _notifications[idx].message,
            videoId: _notifications[idx].videoId,
            senderId: _notifications[idx].senderId,
            commentId: _notifications[idx].commentId,
            isRead: true,
            createdAt: _notifications[idx].createdAt,
          );
          _unreadCount = _notifications.where((n) => !n.isRead).length;
        }
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await VideoNotificationService.markAllAsRead();
      setState(() {
        _notifications = _notifications.map((n) => VideoNotification(
          id: n.id, userId: n.userId, type: n.type, title: n.title,
          message: n.message, videoId: n.videoId, senderId: n.senderId,
          commentId: n.commentId, isRead: true, createdAt: n.createdAt,
        )).toList();
        _unreadCount = 0;
      });
    } catch (e) {
      // Silently fail
    }
  }

  void _onNotificationTap(VideoNotification notification) async {
    if (!notification.isRead) {
      _markAsRead(notification.id);
    }

    if (notification.videoId != null) {
      try {
        final video = await VideoService.getVideo(notification.videoId!);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: video)),
          );
        }
      } catch (e) {
        // Video might not exist
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: GoogleFonts.poppins(color: StarlightTheme.primaryBlue, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.grey, height: 1),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return _buildNotificationItem(notification);
                  },
                ),
    );
  }

  Widget _buildNotificationItem(VideoNotification notification) {
    return InkWell(
      onTap: () => _onNotificationTap(notification),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: notification.isRead ? Colors.transparent : StarlightTheme.primaryBlue.withOpacity(0.05),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.type).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notification.icon,
                color: _getNotificationColor(notification.type),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        notification.timeAgo,
                        style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: StarlightTheme.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_subscriber':
        return Colors.green;
      case 'new_comment':
        return Colors.blue;
      case 'new_like':
        return StarlightTheme.primaryBlue;
      case 'video_ready':
        return Colors.green;
      case 'video_failed':
        return Colors.red;
      case 'video_report':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
