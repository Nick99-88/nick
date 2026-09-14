import 'package:flutter/material.dart';
import '../../../core/socket_vault.dart'; // 🏛️ Your Socket Engine
import '../../../core/theme.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/chat/chat_service.dart';

class TeacherChatMessageScreen extends StatefulWidget {
  final String userName;
  final int chatId;

  const TeacherChatMessageScreen({super.key, required this.userName, required this.chatId});

  @override
  State<TeacherChatMessageScreen> createState() => _TeacherChatMessageScreenState();
}

class _TeacherChatMessageScreenState extends State<TeacherChatMessageScreen> {
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
            "time": data['time'] ?? "Now",
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
    } catch (e) {
      print('Error loading messages: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    
    try {
      await _chatService.sendMessage(
        widget.chatId,
        _messageController.text.trim(),
      );
      
      // Add message to local list immediately for better UX
      setState(() {
        _messages.add({
          "text": _messageController.text.trim(),
          "isMe": true,
          "time": DateTime.now().toString().substring(11, 16),
        });
      });
      
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // TODO: Upload image and send as message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image sharing coming soon!')),
        );
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: StarlightTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: Show user profile
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          
          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['isMe'] ?? false;
    final text = message['text'] ?? '';
    final time = message['time'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: StarlightTheme.primaryBlue,
              child: Text(
                widget.userName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? StarlightTheme.primaryBlue : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.photo_library, color: StarlightTheme.primaryBlue),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Type a message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _isSending ? null : _sendMessage,
            backgroundColor: StarlightTheme.primaryBlue,
            mini: true,
            child: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
