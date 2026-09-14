import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../chat_local_db/repositories/channel_repository.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final ChannelRepository _channelRepo = ChannelRepository();
  bool _isCreating = false;
  String _userId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserId());
  }

  Future<void> _loadUserId() async {
    final phone = await StarlightStorage.getVerifiedPhone();
    if (phone != null) _userId = phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Channel name is required'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final uri = Uri.parse('${StarlightConstants.apiBaseUrl}/api/channels/?created_by=$_userId');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'description': _descController.text.trim(),
          'is_public': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        await _channelRepo.cacheChannelFromServer(
          channelId: data['id'],
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          createdBy: data['created_by'] ?? '',
          isPublic: data['is_public'] ?? true,
          memberUserIds: List<String>.from(data['member_user_ids'] ?? []),
          memberCount: data['member_count'] ?? 0,
          createdAt: data['created_at'] ?? '',
          updatedAt: data['updated_at'] ?? '',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Channel "$name" created!'),
              backgroundColor: const Color(0xFF075E54),
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Failed to create channel: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create channel'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: const Text('Create Channel', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Channel Name',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF263238)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 50,
              decoration: InputDecoration(
                hintText: 'e.g. Tech Discussions',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Description (optional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF263238)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'What is this channel about?',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createChannel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Create Channel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
