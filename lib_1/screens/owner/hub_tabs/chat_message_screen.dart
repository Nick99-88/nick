import 'package:flutter/material.dart';
import 'package:starlight_flutter/core/socket_vault.dart'; // 🏛️ Your Socket Engine
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/l10n/strings.dart';
import 'ChatProfileScreen.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/chat/chat_service.dart';
import '../../../chat_system/services/call_signaling_service.dart';

class ChatMessageScreen extends StatefulWidget {
  final String userName;
  final int chatId;
  final String? peerUserId;
  final String? peerPhone;

  const ChatMessageScreen({
    super.key,
    required this.userName,
    required this.chatId,
    this.peerUserId,
    this.peerPhone,
  });

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();

    // 🏛️ Listen for incoming real-time messages
    StarlightSocket().on("new_message", (data) {
      if (mounted && data['sender'] == widget.userName) {
        setState(() {
          _messages.add({
            "text": data['message'],
            "isMe": false,
            "time": data['time'] ?? tr('now'),
          });
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _chatService.getChatMessages(widget.chatId);
      setState(() => _messages = messages);
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final String text = _messageController.text.trim();
    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(widget.chatId, text);
      
      // Refresh messages
      await _loadMessages();
      
      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('failedSendMessage'))),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      try {
        await _chatService.uploadMedia(widget.chatId, image.path, 'image');
        await _loadMessages();
      } catch (e) {
        print('Error uploading image: $e');
      }
    }
  }

  Future<void> _initiateVoiceCall() async {
    try {
      await _chatService.initiateCall(widget.chatId, callType: 'voice');

      CallSignalingService.instance.startCall(
        peerUserId: widget.peerUserId ?? widget.chatId.toString(),
        peerPhone: widget.peerPhone ?? '',
        peerName: widget.userName,
        type: CallType.voice,
      );
    } catch (e) {
      print('Error initiating call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('failedInitiateCall'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5), // WhatsApp-style background
      appBar: AppBar(
        backgroundColor: StarlightTheme.primaryBlue,
        leadingWidth: 70,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: const [
              SizedBox(width: 8),
              Icon(Icons.arrow_back, color: Colors.white),
              SizedBox(width: 4),
              CircleAvatar(radius: 16, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 20, color: Colors.white)),
            ],
          ),
        ),
        title: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatProfileScreen(userName: widget.userName))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.userName, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              Text(tr('online'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white), 
            onPressed: () {
              // TODO: Implement video call
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('videoCallComingSoon'))),
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white), 
            onPressed: _initiateVoiceCall,
          ),
          _buildMoreMenu(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    // Get current user ID to determine if message is from me
    final currentUserId = 1; // TODO: Get from storage/service
    final isMe = msg['sender_id'] == currentUserId;
    final messageType = msg['message_type'] ?? 'text';
    final content = msg['content'] ?? '';
    final createdAt = msg['created_at'];
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message content based on type
            if (messageType == 'text')
              Text(content, style: const TextStyle(fontSize: 15, color: Colors.black87))
            else if (messageType == 'image')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image, size: 50, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(content, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              )
            else if (messageType == 'voice')
              Row(
                children: [
                  const Icon(Icons.mic, size: 20, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Text(tr('voiceMessage'), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(content, style: const TextStyle(fontSize: 15, color: Colors.black87)),
            
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(createdAt),
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(String? timestamp) {
    if (timestamp == null) return '';
    
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) return tr('justNow');
    if (difference.inHours < 1) return tr('minutesAgo', {'n': '${difference.inMinutes}'});
    if (difference.inDays < 1) return tr('hoursAgo', {'n': '${difference.inHours}'});
    return "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: () {}),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(hintText: tr('messageHint'), border: InputBorder.none),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: () => _showAttachmentSheet(context)),
                  IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: () {}),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: _sendMessage,
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFF075E54),
              child: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER MENUS ---
  Widget _buildMoreMenu() {
    return PopupMenuButton(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      itemBuilder: (context) => [
        PopupMenuItem(child: Text(tr('viewContact'))),
        PopupMenuItem(child: Text(tr('muteNotifications'))),
        PopupMenuItem(child: Text(tr('clearChat'))),
      ],
    );
  }

  void _showAttachmentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        margin: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: GridView.count(
          crossAxisCount: 3,
          padding: const EdgeInsets.all(20),
          children: [
            _attachmentItem(Icons.insert_drive_file, Colors.indigo, tr('attachmentDocument')),
            _attachmentItem(Icons.camera_alt, Colors.pink, tr('attachmentCamera')),
            _attachmentItem(Icons.image, Colors.purple, tr('attachmentGallery')),
            _attachmentItem(Icons.headset, Colors.orange, tr('attachmentAudio')),
            _attachmentItem(Icons.location_on, Colors.green, tr('attachmentLocation')),
            _attachmentItem(Icons.person, Colors.blue, tr('attachmentContact')),
          ],
        ),
      ),
    );
  }

  Widget _attachmentItem(IconData icon, Color color, String label) {
    return Column(
      children: [
        CircleAvatar(radius: 25, backgroundColor: color, child: Icon(icon, color: Colors.white)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}