import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  String _selectedFilter = 'all';
  
  final List<String> _filters = ['all', 'unread', 'important', 'sent'];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    // Simulate loading messages
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _messages = [
        {
          'id': '1',
          'sender': 'System Administrator',
          'subject': 'Welcome to Starlight Mail',
          'preview': 'Get started with your new mailbox...',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
          'isRead': false,
          'isImportant': true,
          'type': 'system',
        },
        {
          'id': '2',
          'sender': 'John Teacher',
          'subject': 'Assignment Update',
          'preview': 'New assignment has been posted for your class...',
          'timestamp': DateTime.now().subtract(const Duration(hours: 5)),
          'isRead': true,
          'isImportant': false,
          'type': 'academic',
        },
        {
          'id': '3',
          'sender': 'Sarah Student',
          'subject': 'Question about homework',
          'preview': 'I have a question about yesterday\'s math homework...',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)),
          'isRead': false,
          'isImportant': false,
          'type': 'student',
        },
        {
          'id': '4',
          'sender': 'Starlight Team',
          'subject': 'New Feature Available',
          'preview': 'Check out the latest features in your dashboard...',
          'timestamp': DateTime.now().subtract(const Duration(days: 2)),
          'isRead': true,
          'isImportant': true,
          'type': 'announcement',
        },
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'INBOX',
          style: GoogleFonts.poppins(
            color: const Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF263238)),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF263238)),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _composeMessage,
        backgroundColor: StarlightTheme.primaryBlue,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                filter.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF263238),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              backgroundColor: isSelected ? StarlightTheme.primaryBlue : Colors.white,
              side: BorderSide(
                color: isSelected ? StarlightTheme.primaryBlue : Colors.grey[300]!,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your inbox is empty for the selected filter',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _messageCard(message);
      },
    );
  }

  Widget _messageCard(Map<String, dynamic> message) {
    final timestamp = message['timestamp'] as DateTime;
    final isUnread = !(message['isRead'] as bool);
    final isImportant = message['isImportant'] as bool;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnread ? StarlightTheme.primaryBlue.withOpacity(0.3) : Colors.grey[200]!,
          width: isUnread ? 2 : 1,
        ),
      ),
      color: isUnread ? Colors.blue.withOpacity(0.05) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getMessageTypeColor(message['type'] as String),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getMessageTypeIcon(message['type'] as String),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                message['sender'] as String,
                style: GoogleFonts.poppins(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                  color: const Color(0xFF263238),
                ),
              ),
            ),
            if (isImportant)
              const Icon(Icons.star, color: Colors.amber, size: 16),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message['subject'] as String,
              style: GoogleFonts.poppins(
                fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF263238),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message['preview'] as String,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(timestamp),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: isUnread
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: StarlightTheme.primaryBlue,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () => _openMessage(message),
      ),
    );
  }

  Color _getMessageTypeColor(String type) {
    switch (type) {
      case 'system':
        return Colors.blue;
      case 'academic':
        return Colors.green;
      case 'student':
        return Colors.orange;
      case 'announcement':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMessageTypeIcon(String type) {
    switch (type) {
      case 'system':
        return Icons.admin_panel_settings;
      case 'academic':
        return Icons.school;
      case 'student':
        return Icons.person;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.mail;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Messages'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: 'Enter search term...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _filters.map((filter) {
            return RadioListTile<String>(
              title: Text(filter.toUpperCase()),
              value: filter,
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openMessage(Map<String, dynamic> message) {
    setState(() {
      message['isRead'] = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening message: ${message['subject']}'),
        backgroundColor: StarlightTheme.primaryBlue,
      ),
    );
  }

  void _composeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compose message feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
