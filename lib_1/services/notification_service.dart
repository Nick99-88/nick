import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/socket/socket_service.dart';
import '../core/theme.dart';
import '../screens/social/chat_screen.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  int? _currentChatId;
  String? _currentUserId;

  // Initialize notification service
  void initialize(String userId, {required BuildContext context}) {
    _currentUserId = userId;
    _setupSocketListeners(context: context);
  }

  // Set current chat ID to track if user is in specific chat
  void setCurrentChatId(int? chatId) {
    _currentChatId = chatId;
  }

  // Setup socket listeners for incoming messages
  void _setupSocketListeners({required BuildContext context}) {
    SocketService.setCallbacks(
      onNewMessage: (data) => _handleIncomingMessage(data, context: context),
      onMessageError: (data) => _handleMessageError(data, context: context),
    );
  }

  // Handle incoming message from socket
  void _handleIncomingMessage(Map<String, dynamic> data, {required BuildContext context}) {
    try {
      print('🏛️ Notification: Received new message - $data');

      final senderId = data['sender_id']?.toString();
      final senderName = data['sender_name'] ?? 'Unknown';
      final messageContent = data['message_content'] ?? '';
      final chatId = data['chat_id'];
      final messageType = data['message_type'] ?? 'text';

      // Check if message is from current user
      if (senderId == _currentUserId) {
        print('🏛️ Notification: Ignoring own message');
        return;
      }

      // Check if user is in the same chat
      if (chatId != null && _currentChatId == chatId) {
        print('🏛️ Notification: User is in same chat, showing message in chat');
        return; // Message will be shown in chat UI
      }

      // Show notification dialog for user in different chat or not in chat
      showMessageNotification(
        context: context,
        senderName: senderName,
        messageContent: messageContent,
        chatId: chatId,
        senderId: senderId,
        messageType: messageType,
      );

    } catch (e) {
      print('🏛️ Notification: Error handling incoming message - $e');
    }
  }

  // Handle message error from socket
  void _handleMessageError(Map<String, dynamic> data, {required BuildContext context}) {
    try {
      print('🏛️ Notification: Received message error - $data');
      
      final errorMessage = data['message'] ?? 'Unknown error';
      
      showErrorNotification(context: context, errorMessage: errorMessage);
      
    } catch (e) {
      print('🏛️ Notification: Error handling message error - $e');
    }
  }

  // Show message notification dialog
  void showMessageNotification({
    required BuildContext context,
    required String senderName,
    required String messageContent,
    int? chatId,
    String? senderId,
    required String messageType,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _MessageNotificationDialog(
          senderName: senderName,
          messageContent: messageContent,
          chatId: chatId,
          senderId: senderId,
          messageType: messageType,
          onOpenChat: () {
            Navigator.of(dialogContext).pop();
            _navigateToChat(context, chatId, senderName);
          },
          onClose: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  // Show error notification
  void showErrorNotification({
    required BuildContext context,
    required String errorMessage,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Message Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Navigate to chat screen
  void _navigateToChat(BuildContext context, int? chatId, String userName) {
    if (chatId == null) {
      print('🏛️ Notification: Cannot navigate - chatId is null');
      return;
    }
    
    try {
      // Navigate to chat message screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            friendId: '',
            friendName: userName,
            friendRole: '',
            friendPhone: userName,
            fromInbox: true,
          ),
        ),
      );
      print('🏛️ Notification: Navigated to chat $chatId with $userName');
    } catch (e) {
      print('🏛️ Notification: Error navigating to chat - $e');
    }
  }

  // Dispose notification service
  void dispose() {
    _currentChatId = null;
    _currentUserId = null;
  }
}

// Custom dialog for message notifications
class _MessageNotificationDialog extends StatefulWidget {
  final String senderName;
  final String messageContent;
  final int? chatId;
  final String? senderId;
  final String messageType;
  final VoidCallback onOpenChat;
  final VoidCallback onClose;

  const _MessageNotificationDialog({
    required this.senderName,
    required this.messageContent,
    this.chatId,
    this.senderId,
    required this.messageType,
    required this.onOpenChat,
    required this.onClose,
  });

  @override
  State<_MessageNotificationDialog> createState() => _MessageNotificationDialogState();
}

class _MessageNotificationDialogState extends State<_MessageNotificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    // Auto-close after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                StarlightTheme.primaryBlue.withOpacity(0.1),
                StarlightTheme.primaryBlue.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with sender info
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: StarlightTheme.primaryBlue,
                    child: Text(
                      widget.senderName.isNotEmpty ? widget.senderName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New message from ${widget.senderName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: StarlightTheme.primaryBlue,
                          ),
                        ),
                        const Text(
                          'Tap to open chat',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Message content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.messageType == 'text')
                      Text(
                        widget.messageContent,
                        style: const TextStyle(fontSize: 14),
                      )
                    else if (widget.messageType == 'image')
                      const Row(
                        children: [
                          Icon(Icons.image, color: StarlightTheme.primaryBlue),
                          SizedBox(width: 8),
                          Text('Image message'),
                        ],
                      )
                    else if (widget.messageType == 'voice')
                      const Row(
                        children: [
                          Icon(Icons.mic, color: StarlightTheme.primaryBlue),
                          SizedBox(width: 8),
                          Text('Voice message'),
                        ],
                      )
                    else
                      Text(
                        widget.messageContent,
                        style: const TextStyle(fontSize: 14),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Later'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: widget.onOpenChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StarlightTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Open Chat'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
