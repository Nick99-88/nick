import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../chat_local_db/repositories/channel_repository.dart';


class SearchChannelScreen extends StatefulWidget {
  const SearchChannelScreen({super.key});

  @override
  State<SearchChannelScreen> createState() => _SearchChannelScreenState();
}

class _SearchChannelScreenState extends State<SearchChannelScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChannelRepository _channelRepo = ChannelRepository();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchChannels(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final uri = Uri.parse('${StarlightConstants.apiBaseUrl}/api/channels/search?q=${Uri.encodeComponent(query)}&user_id=$_userId');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _results = data.cast<Map<String, dynamic>>();
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _joinChannel(Map<String, dynamic> channel) async {
    final channelId = channel['id'] as String;

    try {
      final uri = Uri.parse('${StarlightConstants.apiBaseUrl}/api/channels/$channelId/join?user_id=$_userId');
      final response = await http.post(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Cache locally
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
              content: Text('Joined "${channel['name']}"'),
              backgroundColor: const Color(0xFF075E54),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join channel'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search channels...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (value) => _searchChannels(value),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF075E54)))
          : _results.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Search for public channels'
                            : 'No channels found',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (context, index) => _channelResultTile(_results[index]),
                ),
    );
  }

  Widget _channelResultTile(Map<String, dynamic> channel) {
    final name = channel['name'] ?? '';
    final description = channel['description'] ?? '';
    final memberCount = channel['member_count'] ?? 0;
    final isMember = channel['am_i_member'] ?? false;

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF075E54).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.campaign, color: Color(0xFF075E54), size: 24),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        description.isNotEmpty ? description : '$memberCount members',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isMember
          ? TextButton(
              onPressed: null,
              child: const Text('Joined', style: TextStyle(color: Colors.grey)),
            )
          : TextButton(
              onPressed: () => _joinChannel(channel),
              child: const Text('Join'),
            ),
    );
  }
}
