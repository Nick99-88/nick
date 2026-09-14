import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../chat_local_db/chat_local_db.dart';
import '../../services/socket/enhanced_socket_service.dart';

class ContactProfileScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendPhone;
  final String? friendProfilePicture;

  const ContactProfileScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendPhone,
    this.friendProfilePicture,
  });

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen> {
  String _name = '';
  String _phone = '';
  String _about = '';
  String _lastSeen = '';
  bool _isOnline = false;
  String? _profileImageUrl;
  bool _isLoading = true;
  Completer<void>? _profileCompleter;

  @override
  void initState() {
    super.initState();
    _name = widget.friendName;
    _phone = widget.friendPhone ?? '';
    _fetchProfile();
  }

  void _fetchProfile() {
    _profileCompleter = Completer<void>();
    
    EnhancedSocketService.setProfileUpdatedCallback(_handleProfileUpdate);
    
    final socket = EnhancedSocketService.socket;
    if (socket != null) {
      socket.sink.add(jsonEncode({
        'action': 'get_user_profile',
        'user_id': widget.friendId,
      }));
      
      Future.delayed(const Duration(seconds: 5), () {
        if (!_profileCompleter!.isCompleted) {
          _profileCompleter!.complete();
          if (mounted) setState(() => _isLoading = false);
        }
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _handleProfileUpdate(Map<String, dynamic> data) {
    if (data['found'] == true && mounted) {
      setState(() {
        _name = data['name'] ?? widget.friendName;
        _phone = data['phone'] ?? widget.friendPhone ?? '';
        _about = data['about'] ?? '';
        _lastSeen = data['last_seen'] ?? '';
        _isOnline = data['is_online'] ?? false;
        _profileImageUrl = data['profile_image_url'];
        _isLoading = false;
      });
      
      if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
        _downloadProfilePicture(_profileImageUrl!);
      }
      
      if (!_profileCompleter!.isCompleted) {
        _profileCompleter!.complete();
      }
    } else if (data['found'] == false && mounted) {
      setState(() => _isLoading = false);
      if (!_profileCompleter!.isCompleted) {
        _profileCompleter!.complete();
      }
    }
  }

  Future<void> _downloadProfilePicture(String serverUrl) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final fullUrl = serverUrl.startsWith('http') 
          ? serverUrl 
          : '${StarlightConstants.apiBaseUrl}$serverUrl';
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final profileDir = Directory('${directory.path}/profile_pictures');
        if (!await profileDir.exists()) await profileDir.create(recursive: true);
        final filename = '${_phone.replaceAll("+", "")}.jpg';
        final filePath = '${profileDir.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          setState(() => _profileImageUrl = filePath);
        }
      }
    } catch (e) {
      debugPrint("Download profile picture error: $e");
    }
  }

  String _formatLastSeen(String lastSeenStr) {
    if (lastSeenStr.isEmpty) return 'Offline';
    try {
      final dt = DateTime.parse(lastSeenStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Last seen just now';
      if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
      if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Last seen yesterday';
      return 'Last seen ${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Offline';
    }
  }

  String _formatPhoneNumber(String phone) {
    if (phone.isEmpty) return phone;
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 12 && cleaned.startsWith('92')) {
      return '+92 ${cleaned.substring(2, 5)} ${cleaned.substring(5)}';
    } else if (cleaned.length == 10 && cleaned.startsWith('0')) {
      return '+92 ${cleaned.substring(1, 4)} ${cleaned.substring(4)}';
    } else if (cleaned.length == 9 && !cleaned.startsWith('0')) {
      return '+92 ${cleaned.substring(0, 3)} ${cleaned.substring(3)}';
    }
    return phone;
  }

  void _showFullImage() {
    if (_profileImageUrl == null || _profileImageUrl!.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: File(_profileImageUrl!).existsSync()
                  ? Image.file(File(_profileImageUrl!), fit: BoxFit.contain)
                  : Container(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF263238),
        ),
        title: const Text(
          'Contact Info',
          style: TextStyle(
            color: Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Profile Picture
                  Center(
                    child: GestureDetector(
                      onTap: _showFullImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _profileImageUrl != null && 
                            _profileImageUrl!.isNotEmpty &&
                            File(_profileImageUrl!).existsSync()
                            ? FileImage(File(_profileImageUrl!))
                            : null,
                        child: (_profileImageUrl == null || 
                                _profileImageUrl!.isEmpty ||
                                !File(_profileImageUrl!).existsSync())
                            ? Text(
                                _name.isNotEmpty ? _name[0].toUpperCase() : '#',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 48,
                                  color: Color(0xFF263238),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    _name.isNotEmpty ? _name : 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFF263238),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Phone
                  if (_phone.isNotEmpty)
                    Text(
                      _formatPhoneNumber(_phone),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Online status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.green[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'Online' : _formatLastSeen(_lastSeen),
                          style: TextStyle(
                            fontSize: 13,
                            color: _isOnline ? Colors.green : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // About
                  if (_about.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _about,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF263238),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            icon: Icons.message_rounded,
                            label: 'Message',
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_phone.isNotEmpty)
                          Expanded(
                            child: _actionButton(
                              icon: Icons.phone_rounded,
                              label: 'Call',
                              onTap: () => _launchPhone(_phone),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Share button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: _actionButton(
                        icon: Icons.share_rounded,
                        label: 'Share Contact',
                        onTap: _showShareUserSheet,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF075E54),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchPhone(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showShareUserSheet() async {
    try {
      final chatRepository = ChatRepository();
      final chats = await chatRepository.getAllChats(includeArchived: true);
      
      if (!mounted) return;
      
      if (chats.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No chats available to share to')),
        );
        return;
      }
      
      final selectedChats = <LocalChat>{};
      String searchQuery = '';
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (ctx, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Share to',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        onChanged: (value) {
                          setSheetState(() => searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setSheetState(() => searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedChats.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${selectedChats.length} selected',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() => selectedChats.clear());
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: chats.where((c) {
                      if (searchQuery.isEmpty) return true;
                      final q = searchQuery.toLowerCase();
                      return c.contactName.toLowerCase().contains(q) ||
                          c.phoneNumber.contains(searchQuery);
                    }).length,
                    itemBuilder: (context, index) {
                      final filteredChats = chats.where((c) {
                        if (searchQuery.isEmpty) return true;
                        final q = searchQuery.toLowerCase();
                        return c.contactName.toLowerCase().contains(q) ||
                            c.phoneNumber.contains(searchQuery);
                      }).toList();
                      
                      final chat = filteredChats[index];
                      final isSelected = selectedChats.contains(chat);
                      final displayName = chat.contactName.isNotEmpty 
                          ? chat.contactName 
                          : chat.phoneNumber;
                      
                      return CheckboxListTile(
                        value: isSelected,
                        secondary: CircleAvatar(
                          backgroundColor: const Color(0xFF075E54),
                          child: Text(
                            displayName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(displayName),
                        subtitle: Text(_formatPhoneNumber(chat.phoneNumber)),
                        onChanged: (value) {
                          setSheetState(() {
                            if (value == true) {
                              selectedChats.add(chat);
                            } else {
                              selectedChats.remove(chat);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                if (selectedChats.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _sendContactToSelectedChats(selectedChats.toList());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF075E54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Send to ${selectedChats.length} chat(s)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('Share user sheet error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: $e')),
        );
      }
    }
  }

  void _sendContactToSelectedChats(List<LocalChat> selectedChats) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final socket = EnhancedSocketService.socket;
      if (socket == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not connected to server')),
          );
        }
        return;
      }

      final contactData = jsonEncode({
        'name': _name,
        'phone': _phone,
      });

      for (final chat in selectedChats) {
        final clientUuid = DateTime.now().microsecondsSinceEpoch.toString();
        
        // Get recipient ID
        String recipientId = chat.peerUserId;
        if (recipientId.isEmpty) {
          // Try to get from server
          recipientId = await _getUserIdFromPhone(chat.phoneNumber) ?? '';
        }
        
        if (recipientId.isEmpty) {
          print('Could not find user ID for phone: ${chat.phoneNumber}');
          continue;
        }

        // Save to local DB first
        final msgRepo = MessageRepository();
        final localMsg = LocalMessage(
          chatPhoneNumber: chat.phoneNumber,
          peerUserId: recipientId,
          sequenceId: 0,
          clientUuid: clientUuid,
          messageType: 'share_contact',
          messageDirection: 'sent',
          content: contactData,
          mediaLocalPath: '',
          mediaRemoteUrl: '',
          mediaFileName: '',
          mediaThumbnailPath: '',
          status: 'sending',
          serverMessageId: '',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
        
        try {
          await msgRepo.insertMessage(localMsg);
          
          final chatRepo = ChatRepository();
          await chatRepo.updateLastMessage(
            chat.phoneNumber,
            'Contact: $_name',
            'share_contact',
          );
        } catch (e) {
          print('Error saving to local DB: $e');
        }

        // Send via socket
        socket.sink.add(jsonEncode({
          'action': 'send_message',
          'recipient_id': recipientId,
          'content': contactData,
          'message_type': 'share_contact',
          'client_uuid': clientUuid,
        }));

        print('Share contact sent to ${chat.contactName}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact shared to ${selectedChats.length} chat(s)')),
        );
      }
    } catch (e) {
      print('Error sending contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing contact: $e')),
        );
      }
    }
  }

  Future<String?> _getUserIdFromPhone(String phone) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/chat/validate-phone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'phone_number': phone}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['exists'] == true) {
          return data['user_id'];
        }
      }
    } catch (e) {
      print('Error getting user ID: $e');
    }
    return null;
  }
}
