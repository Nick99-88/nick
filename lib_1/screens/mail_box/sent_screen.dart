import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class SentScreen extends StatefulWidget {
  const SentScreen({super.key});

  @override
  State<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends State<SentScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sentMessages = [];

  @override
  void initState() {
    super.initState();
    _loadSentMessages();
  }

  Future<void> _loadSentMessages() async {
    // Simulate loading sent messages
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _sentMessages = [
        {
          'id': '1',
          'recipient': 'John Teacher',
          'subject': 'Assignment Submission',
          'preview': 'Please find attached homework for Chapter 5...',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
          'status': 'delivered',
          'type': 'academic',
        },
        {
          'id': '2',
          'recipient': 'Sarah Student',
          'subject': 'Homework Help',
          'preview': 'Here are the solutions for yesterday\'s problems...',
          'timestamp': DateTime.now().subtract(const Duration(hours: 3)),
          'status': 'delivered',
          'type': 'student',
        },
        {
          'id': '3',
          'recipient': 'All Students',
          'subject': 'Class Schedule Update',
          'preview': 'Tomorrow\'s schedule has been updated...',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)),
          'status': 'delivered',
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
          'SENT',
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sentMessages.isEmpty
              ? _buildEmptyState()
              : _buildSentMessagesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.send_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No sent messages',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your sent messages will appear here',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentMessagesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sentMessages.length,
      itemBuilder: (context, index) {
        final message = _sentMessages[index];
        return _sentMessageCard(message);
      },
    );
  }

  Widget _sentMessageCard(Map<String, dynamic> message) {
    final timestamp = message['timestamp'] as DateTime;
    final status = message['status'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getStatusColor(status),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(status),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          message['recipient'] as String,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: const Color(0xFF263238),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message['subject'] as String,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
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
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(status),
            ),
          ),
        ),
        onTap: () => _openSentMessage(message),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'delivered':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'failed':
        return Icons.error;
      default:
        return Icons.help;
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
        title: const Text('Search Sent Messages'),
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

  void _openSentMessage(Map<String, dynamic> message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening sent message: ${message['subject']}'),
        backgroundColor: StarlightTheme.primaryBlue,
      ),
    );
  }
}
