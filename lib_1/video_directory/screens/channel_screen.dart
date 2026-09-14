import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../models/video_models.dart';
import '../services/video_service.dart';
import '../widgets/video_widgets.dart';
import 'video_player_screen.dart';

class ChannelScreen extends StatefulWidget {
  final String channelId;
  final String? initialName;

  const ChannelScreen({super.key, required this.channelId, this.initialName});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  Channel? _channel;
  List<VideoPost> _videos = [];
  bool _isLoading = true;
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        VideoService.getChannel(widget.channelId),
        VideoService.getUserVideos(widget.channelId),
      ]);
      if (mounted) {
        final channel = results[0] as Channel;
        setState(() {
          _channel = channel;
          _videos = results[1] as List<VideoPost>;
          _isSubscribed = channel.isSubscribed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSubscribe() async {
    if (_channel == null) return;
    try {
      final res = await VideoService.toggleSubscribe(widget.channelId);
      setState(() {
        _isSubscribed = res;
        _channel = Channel(
          id: _channel!.id, name: _channel!.name,
          avatar: _channel!.avatar, banner: _channel!.banner,
          description: _channel!.description,
          subscriberCount: _channel!.subscriberCount + (res ? 1 : -1),
          isSubscribed: res, videoCount: _channel!.videoCount,
          hasChannel: _channel!.hasChannel, links: _channel!.links,
          isOwner: _channel!.isOwner, createdAt: _channel!.createdAt,
          totalViews: _channel!.totalViews,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: _channel?.name ?? '');
    final descCtrl = TextEditingController(text: _channel?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Edit Channel', style: GoogleFonts.poppins(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true, fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true, fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                final channel = await VideoService.updateChannel(
                  name: name,
                  description: descCtrl.text.trim(),
                  links: jsonEncode(_channel!.links),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _channel = channel);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddLinkDialog({int? editIndex}) {
    final titleCtrl = TextEditingController(
      text: editIndex != null ? _channel!.links[editIndex]['title'] ?? '' : '',
    );
    final urlCtrl = TextEditingController(
      text: editIndex != null ? _channel!.links[editIndex]['url'] ?? '' : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(editIndex != null ? 'Edit Link' : 'Add Link',
            style: GoogleFonts.poppins(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true, fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'URL',
                labelStyle: TextStyle(color: Colors.grey),
                filled: true, fillColor: Color(0xFF2A2A2A),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (title.isEmpty || url.isEmpty) return;
              final links = List<Map<String, String>>.from(_channel!.links);
              if (editIndex != null) {
                links[editIndex] = {'title': title, 'url': url};
              } else {
                links.add({'title': title, 'url': url});
              }
              try {
                final channel = await VideoService.updateChannel(
                  name: _channel!.name,
                  description: _channel!.description ?? '',
                  links: jsonEncode(links),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() => _channel = channel);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue),
            child: Text(editIndex != null ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _deleteLink(int index) {
    final links = List<Map<String, String>>.from(_channel!.links);
    links.removeAt(index);
    VideoService.updateChannel(
      name: _channel!.name,
      description: _channel!.description ?? '',
      links: jsonEncode(links),
    ).then((channel) {
      if (mounted) setState(() => _channel = channel);
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _channel?.name ?? widget.initialName ?? 'Channel',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: _channel != null && _channel!.isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: _showEditDialog,
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _channel == null
              ? Center(
                  child: Text('Channel not found', style: GoogleFonts.poppins(color: Colors.grey)),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView(
      children: [
        _buildHeader(),
        const Divider(color: Colors.grey, height: 1),
        if (_channel!.description != null && _channel!.description!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              _channel!.description!,
              style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 14),
            ),
          ),
        ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text('Links', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                if (_channel!.isOwner)
                  TextButton.icon(
                    onPressed: () => _showAddLinkDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Link'),
                    style: TextButton.styleFrom(foregroundColor: StarlightTheme.primaryBlue),
                  ),
              ],
            ),
          ),
          if (_channel!.links.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('No links yet', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
            )
          else
            ..._channel!.links.asMap().entries.map((entry) {
              final i = entry.key;
              final link = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 18, color: StarlightTheme.primaryBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              link['title'] ?? '',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              link['url'] ?? '',
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link['url'] ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 1)),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (_channel!.isOwner) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                          onPressed: () => _showAddLinkDialog(editIndex: i),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                          onPressed: () => _deleteLink(i),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
        const SizedBox(height: 8),
        const Divider(color: Colors.grey, height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Channel Details', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.people, '${_formatCount(_channel!.subscriberCount)} subscribers'),
              _buildDetailRow(Icons.videocam, '${_channel!.videoCount} videos'),
              _buildDetailRow(Icons.visibility, '${_formatCount(_channel!.totalViews)} total views'),
              if (_channel!.createdAt != null && _channel!.createdAt!.isNotEmpty)
                _buildDetailRow(Icons.calendar_today, 'Since ${_formatDate(_channel!.createdAt!)}'),
            ],
          ),
        ),
        const Divider(color: Colors.grey, height: 1),
        if (!_channel!.isOwner) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Videos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (_videos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No videos yet', style: GoogleFonts.poppins(color: Colors.grey)),
              ),
            )
          else
            ..._videos.map((v) => VideoWidgets.buildVideoCard(
              context, v,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(video: v))),
            )),
        ],
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: StarlightTheme.primaryBlue,
            child: Text(
              _channel!.name.isNotEmpty ? _channel!.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _channel!.name,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatCount(_channel!.subscriberCount)} subscribers • ${_channel!.videoCount} videos',
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (!_channel!.isOwner)
            ElevatedButton(
              onPressed: _toggleSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSubscribed ? Colors.grey : StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
            ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      final abs = diff.isNegative ? -diff : diff;
      if (abs.inDays > 365) return '${(abs.inDays ~/ 365)}y';
      if (abs.inDays > 30) return '${(abs.inDays ~/ 30)}mo';
      if (abs.inDays > 0) return '${abs.inDays}d';
      return 'Today';
    } catch (e) {
      return dateStr;
    }
  }
}
