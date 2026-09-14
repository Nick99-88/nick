import 'package:flutter/material.dart';
import '../../chat_local_db/models/local_channel.dart';
import '../../chat_local_db/repositories/channel_repository.dart';
import 'search_channel_screen.dart';
import 'create_channel_screen.dart';

class ChannelsListScreen extends StatefulWidget {
  const ChannelsListScreen({super.key});

  @override
  State<ChannelsListScreen> createState() => _ChannelsListScreenState();
}

class _ChannelsListScreenState extends State<ChannelsListScreen> {
  final ChannelRepository _channelRepo = ChannelRepository();
  List<LocalChannel> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() => _isLoading = true);
    final channels = await _channelRepo.getActiveChannels();
    setState(() {
      _channels = channels;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        title: const Text('Channels', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _openSearchChannel,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _openCreateChannel,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF075E54)))
          : _channels.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadChannels,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _channels.length,
                    itemBuilder: (context, index) => _channelTile(_channels[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No channels yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF263238)),
          ),
          const SizedBox(height: 8),
          Text(
            'Create or join a channel to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _openCreateChannel,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Channel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: _openSearchChannel,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF075E54),
                  side: const BorderSide(color: Color(0xFF075E54)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _channelTile(LocalChannel channel) {
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
      title: Text(
        channel.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        channel.lastMessage.isNotEmpty
            ? channel.displayLastMessage
            : '${channel.memberCount} members',
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: channel.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF075E54),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: Text(
                '${channel.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          : Text(
              channel.lastMessageTime.isNotEmpty ? _formatTime(channel.lastMessageTime) : '',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
      onTap: () => _openChannelChat(channel),
      onLongPress: () => _showChannelOptions(channel),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return '${dt.day}/${dt.month}';
      }
    } catch (_) {
      return '';
    }
  }

  void _openSearchChannel() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchChannelScreen()),
    );
    if (result == true) _loadChannels();
  }

  void _openCreateChannel() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateChannelScreen()),
    );
    if (result == true) _loadChannels();
  }

  void _openChannelChat(LocalChannel channel) {
    // TODO: Navigate to channel chat screen
  }

  void _showChannelOptions(LocalChannel channel) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Channel Info'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: Navigate to channel info
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(channel.isPinned ? 'Unpin' : 'Pin'),
              onTap: () async {
                Navigator.pop(ctx);
                await _channelRepo.togglePin(channel.channelId);
                _loadChannels();
              },
            ),
            ListTile(
              leading: Icon(channel.isMuted ? Icons.volume_up : Icons.volume_off),
              title: Text(channel.isMuted ? 'Unmute' : 'Mute'),
              onTap: () async {
                Navigator.pop(ctx);
                await _channelRepo.toggleMute(channel.channelId);
                _loadChannels();
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive'),
              onTap: () async {
                Navigator.pop(ctx);
                await _channelRepo.toggleArchive(channel.channelId);
                _loadChannels();
              },
            ),
            if (channel.amIAdmin)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Channel', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteChannel(channel);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChannel(LocalChannel channel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Channel?'),
        content: Text('Are you sure you want to delete "${channel.displayName}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _channelRepo.deleteChannel(channel.channelId);
              _loadChannels();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
