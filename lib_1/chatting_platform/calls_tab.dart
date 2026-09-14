import 'package:flutter/material.dart';
import '../../chat_local_db/models/local_call_log.dart';
import '../../chat_local_db/repositories/call_log_repository.dart';

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LocalCallLog>>(
      future: CallLogRepository().getAllCallLogs(),
      builder: (context, snapshot) {
        final callLogs = snapshot.data ?? [];
        
        return Column(
          children: [
            // Top buttons row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _callActionButton(
                    icon: Icons.dialpad,
                    label: 'Keypad',
                    onTap: _showKeypad,
                  ),
                  _callActionButton(
                    icon: Icons.person_add_outlined,
                    label: 'New call',
                    onTap: () {},
                  ),
                  _callActionButton(
                    icon: Icons.link,
                    label: 'Invite',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Call logs header
            if (callLogs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Recent',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await CallLogRepository().clearCallLogs();
                        setState(() {});
                      },
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
              ),
            // Call logs list
            Expanded(
              child: callLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call_outlined, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No recent calls',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your call history will appear here',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: callLogs.length,
                      itemBuilder: (context, index) {
                        final log = callLogs[index];
                        return _callLogTile(log);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _callActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF075E54).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF075E54), size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF263238)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callLogTile(LocalCallLog log) {
    final isMissed = log.callState == 'missed';
    final isOutgoing = log.callDirection == 'outgoing';
    final displayName = log.peerName.isNotEmpty ? log.peerName : log.peerUserId;
    
    IconData callIcon;
    Color iconColor;
    
    if (isMissed) {
      callIcon = Icons.call_received;
      iconColor = Colors.red;
    } else if (isOutgoing) {
      callIcon = Icons.call_made;
      iconColor = Colors.green;
    } else {
      callIcon = Icons.call_received;
      iconColor = Colors.green;
    }
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[200],
        backgroundImage: log.peerAvatar.isNotEmpty
            ? NetworkImage(log.peerAvatar) as ImageProvider
            : null,
        child: log.peerAvatar.isNotEmpty
            ? null
            : Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '#',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF263238)),
              ),
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isMissed ? Colors.red : const Color(0xFF263238),
        ),
      ),
      subtitle: Row(
        children: [
          Icon(callIcon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            '${log.callType == 'video' ? 'Video' : 'Voice'} · ${_formatCallDuration(log.duration)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              log.callType == 'video' ? Icons.videocam : Icons.phone,
              color: const Color(0xFF075E54),
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.grey),
            onPressed: () {
              _showCallLogDetails(log);
            },
          ),
        ],
      ),
    );
  }

  String _formatCallDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) return '${minutes}m ${remainingSeconds}s';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes}m';
  }

  void _showCallLogDetails(LocalCallLog log) {
    final displayName = log.peerName.isNotEmpty ? log.peerName : log.peerUserId;
    
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: log.peerAvatar.isNotEmpty
                      ? NetworkImage(log.peerAvatar) as ImageProvider
                      : null,
                  child: log.peerAvatar.isNotEmpty
                      ? null
                      : Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '#',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        _formatCallLogTime(log.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _callLogDetailRow(
              Icons.call,
              'Type',
              '${log.callType == 'video' ? 'Video' : 'Voice'} call',
            ),
            _callLogDetailRow(
              log.callDirection == 'outgoing' ? Icons.call_made : Icons.call_received,
              'Direction',
              log.callDirection == 'outgoing' ? 'Outgoing' : 'Incoming',
            ),
            _callLogDetailRow(
              Icons.access_time,
              'Duration',
              _formatCallDuration(log.duration),
            ),
            _callLogDetailRow(
              Icons.circle,
              'Status',
              log.callState.toUpperCase(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _callLogAction(
                  icon: Icons.phone,
                  label: 'Audio',
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
                _callLogAction(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
                _callLogAction(
                  icon: Icons.message,
                  label: 'Message',
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _callLogDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _callLogAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF075E54), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF075E54)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCallLogTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        return 'Today ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        return 'Yesterday ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return '${days[dt.weekday - 1]} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {
      return '';
    }
  }

  void _showKeypad() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _KeypadSheet(),
    );
  }
}

class _KeypadSheet extends StatefulWidget {
  const _KeypadSheet();

  @override
  State<_KeypadSheet> createState() => _KeypadSheetState();
}

class _KeypadSheetState extends State<_KeypadSheet> {
  String _number = '';

  void _onKeyPressed(String value) {
    setState(() => _number += value);
  }

  void _onBackspace() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _number.isEmpty ? 'Enter number' : _number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: _number.isEmpty ? Colors.grey[400] : const Color(0xFF263238),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Keypad grid
          _buildKeypadRow(['1', '2', '3']),
          const SizedBox(height: 12),
          _buildKeypadRow(['4', '5', '6']),
          const SizedBox(height: 12),
          _buildKeypadRow(['7', '8', '9']),
          const SizedBox(height: 12),
          _buildKeypadRow(['*', '0', '#']),
          const SizedBox(height: 20),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.videocam, size: 28),
                color: const Color(0xFF075E54),
                onPressed: _number.isEmpty ? null : () {},
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF075E54),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.phone, size: 28),
                  color: Colors.white,
                  onPressed: _number.isEmpty ? null : () {},
                ),
              ),
              IconButton(
                icon: const Icon(Icons.backspace_outlined, size: 28),
                color: Colors.grey[600],
                onPressed: _number.isEmpty ? null : _onBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((n) => _buildKey(n)).toList(),
    );
  }

  Widget _buildKey(String value) {
    return GestureDetector(
      onTap: () => _onKeyPressed(value),
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Color(0xFF263238),
            ),
          ),
        ),
      ),
    );
  }
}
