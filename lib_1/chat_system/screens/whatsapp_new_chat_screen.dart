import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/screens/social/chat_screen.dart';
import 'package:starlight_flutter/chat_system/services/contact_verification_service.dart';
import 'package:starlight_flutter/chat_local_db/chat_local_db.dart';

class WhatsAppNewChatScreen extends StatefulWidget {
  const WhatsAppNewChatScreen({super.key});

  @override
  State<WhatsAppNewChatScreen> createState() => _WhatsAppNewChatScreenState();
}

class _WhatsAppNewChatScreenState extends State<WhatsAppNewChatScreen> {
  final _searchController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  String _searchQuery = '';
  List<LocalChat> _existingChats = [];
  bool _isLoading = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadExistingChats();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await ChatRepository().getAllChats(
        includeArchived: false,
        includeBlocked: false,
      );
      if (mounted) setState(() => _existingChats = chats);
    } catch (e) {
      print('Error loading chats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<LocalChat> get _filteredChats {
    if (_searchQuery.isEmpty) return _existingChats;
    return _existingChats.where((chat) {
      return chat.contactName.toLowerCase().contains(_searchQuery) ||
          chat.phoneNumber.contains(_searchQuery);
    }).toList();
  }

  Future<void> _verifyAndNavigate(String phone, String name) async {
    setState(() => _isVerifying = true);

    final result = await ContactVerificationService.verify(phone);

    if (!mounted) return;

    final repo = ChatRepository();
    final chat = await repo.getOrCreateChat(
      phone,
      contactName: name.isNotEmpty ? name : null,
      peerUserId: result.peerUserId,
    );

    if (result.exists && result.profileImageUrl != null && result.profileImageUrl!.isNotEmpty) {
      await repo.updateChat(chat.copyWith(profileImageUrl: result.profileImageUrl));
    }

    setState(() => _isVerifying = false);

    if (result.exists || !result.verified) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            friendId: '',
            friendName: name.isNotEmpty ? name : null,
            friendRole: '',
            friendPhone: phone,
            fromInbox: false,
          ),
        ),
      );
    } else {
      _showInviteDialog(phone, name);
    }
  }

  void _showInviteDialog(String phone, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('User Not Found'),
        content: Text('$phone is not registered on Starlight. Would you like to invite them?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    friendId: '',
                    friendName: name.isNotEmpty ? name : null,
                    friendRole: '',
                    friendPhone: phone,
                    fromInbox: false,
                  ),
                ),
              );
            },
            child: const Text('Chat Anyway'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Invite'),
            onPressed: () {
              Navigator.pop(ctx);
              SharePlus.instance.share(
                ShareParams(
                  text: 'Join me on Starlight! Download the app to chat with me.',
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    _phoneController.clear();
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+923XXXXXXXXX',
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'John Doe',
                labelText: 'Contact Name (optional)',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = _phoneController.text.trim();
              if (phone.isEmpty) return;
              final name = _nameController.text.trim();
              Navigator.pop(context);
              _verifyAndNavigate(phone, name);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: StarlightTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add & Chat'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(LocalChat chat) {
    if (chat.profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(chat.profileImageUrl),
        backgroundColor: Colors.grey.shade200,
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: StarlightTheme.primaryBlue,
      child: Text(
        chat.contactName.isNotEmpty ? chat.contactName[0].toUpperCase() : '?',
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        backgroundColor: StarlightTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddContactDialog,
            tooltip: 'Add Contact',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(child: _buildContactList()),
            ],
          ),
          if (_isVerifying)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text('Verifying contact...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final filtered = _filteredChats;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_alt_1, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No contacts yet',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add a contact by phone number',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final chat = filtered[index];
        return ListTile(
          leading: _buildAvatar(chat),
          title: Text(
            chat.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(chat.phoneNumber),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  friendId: chat.peerUserId ?? '',
                  friendName: chat.contactName.isNotEmpty ? chat.contactName : null,
                  friendRole: '',
                  friendPhone: chat.phoneNumber,
                  fromInbox: false,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
