import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/storage.dart';
import '../../../core/sign.dart';
import '../../../core/constants.dart';
import '../../../services/institution/directory_service.dart';
import '../../../l10n/strings.dart';

class ActivityLogEntry {
  final String id;
  final String userName;
  final String userId;
  final String userRole;
  final String actorName;
  final String actorId;
  final String actionType;
  final String details;
  final String timestamp;
  final String? profilePhoto;

  ActivityLogEntry({
    required this.id,
    required this.userName,
    this.userId = '',
    this.userRole = '',
    this.actorName = '',
    this.actorId = '',
    required this.actionType,
    this.details = '',
    required this.timestamp,
    this.profilePhoto,
  });

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    final log = json['log'] ?? json;
    return ActivityLogEntry(
      id: log['id']?.toString() ?? '',
      userName: log['user_name'] ?? log['name'] ?? 'Unknown',
      userId: log['user_id'] ?? '',
      userRole: log['user_role'] ?? log['role'] ?? '',
      actorName: log['actor_name'] ?? log['accepted_by_name'] ?? '',
      actorId: log['actor_id'] ?? '',
      actionType: log['action_type'] ?? 'ACTIVITY',
      details: log['details'] ?? '',
      timestamp: log['timestamp'] ??
          log['joined_date'] ??
          log['created_at'] ??
          DateTime.now().toIso8601String(),
      profilePhoto: log['profile_photo'] ?? log['pfp'],
    );
  }
}

class ActivityLogsScreen extends StatefulWidget {
  final VoidCallback onClose;
  const ActivityLogsScreen({super.key, required this.onClose});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final DirectoryService _directoryService = DirectoryService();
  List<ActivityLogEntry> allLogs = [];
  bool isLoading = true;
  String selectedFilter = 'ALL';

  final List<Map<String, dynamic>> _filters = [
    {'labelKey': 'actLogFilterAll', 'value': 'ALL'},
    {'labelKey': 'actLogFilterJoined', 'value': 'JOINED'},
    {'labelKey': 'actLogFilterAccepted', 'value': 'ACCEPTED'},
    {'labelKey': 'actLogFilterRejected', 'value': 'REJECTED'},
    {'labelKey': 'actLogFilterKicked', 'value': 'KICKED'},
    {'labelKey': 'actLogFilterBlocked', 'value': 'BLOCKED'},
    {'labelKey': 'actLogFilterUnblocked', 'value': 'UNBLOCKED'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllLogs();
  }

  Future<void> _fetchAllLogs() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        _loadMockLogs();
        return;
      }

      final activityRes = await http.get(
        Uri.parse(
            "${StarlightConstants.apiBaseUrl}/institution/directory/activity-logs"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      final joinRes = await http.get(
        Uri.parse(
            "${StarlightConstants.apiBaseUrl}/institution/directory/join-logs"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      List<ActivityLogEntry> merged = [];

      if (activityRes.statusCode == 200) {
        final List<dynamic> activityData = jsonDecode(activityRes.body);
        for (final item in activityData) {
          merged.add(ActivityLogEntry.fromJson(item));
        }
      }

      if (joinRes.statusCode == 200) {
        final List<dynamic> joinData = jsonDecode(joinRes.body);
        for (final item in joinData) {
          merged.add(ActivityLogEntry.fromJson(item));
        }
      }

      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          allLogs = merged;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Logs Fetch Error: $e");
      _loadMockLogs();
    }
  }

  void _loadMockLogs() {
    setState(() {
      allLogs = [
        ActivityLogEntry(
            id: '1',
            userName: 'Abbass Ali',
            userRole: 'teacher',
            actorName: 'Owner Hassan',
            actionType: 'ACCEPTED',
            details: 'Join request approved',
            timestamp: DateTime.now().toIso8601String()),
        ActivityLogEntry(
            id: '2',
            userName: 'Ahmad Khan',
            userRole: 'student',
            actorName: 'Owner Hassan',
            actionType: 'JOINED',
            details: 'Joined via access key',
            timestamp: DateTime.now()
                .subtract(const Duration(hours: 2))
                .toIso8601String()),
        ActivityLogEntry(
            id: '3',
            userName: 'Zahid Ullah',
            userRole: 'staff',
            actorName: 'Owner Hassan',
            actionType: 'KICKED',
            details: 'Removed for policy violation',
            timestamp: DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String()),
        ActivityLogEntry(
            id: '4',
            userName: 'Ali Raza',
            userRole: 'student',
            actorName: 'Owner Hassan',
            actionType: 'BLOCKED',
            details: 'Blocked for misconduct',
            timestamp: DateTime.now()
                .subtract(const Duration(days: 2))
                .toIso8601String()),
        ActivityLogEntry(
            id: '5',
            userName: 'Ali Raza',
            userRole: 'student',
            actorName: 'Owner Hassan',
            actionType: 'UNBLOCKED',
            details: 'Restriction lifted',
            timestamp: DateTime.now()
                .subtract(const Duration(days: 3))
                .toIso8601String()),
        ActivityLogEntry(
            id: '6',
            userName: 'Sara Khan',
            userRole: 'teacher',
            actorName: 'Owner Hassan',
            actionType: 'REJECTED',
            details: 'Join request denied',
            timestamp: DateTime.now()
                .subtract(const Duration(days: 5))
                .toIso8601String()),
      ];
      isLoading = false;
    });
  }

  List<ActivityLogEntry> get filteredLogs {
    if (selectedFilter == 'ALL') return allLogs;
    return allLogs
        .where((log) => log.actionType.toUpperCase() == selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Color(0xFF1E293B)),
            onPressed: widget.onClose,
          ),
        ),
        title: Text(
          tr('actLogTitle'),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Banner matching the Vault theme style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF1D4ED8),
                    Color(0xFF2563EB)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tr('actLogAuditTrail'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr('actLogStream'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('actLogDesc'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter Chips Row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _filters
                    .map((f) => _buildFilterChip(
                        tr(f['labelKey'] as String), f['value'] as String))
                    .toList(),
              ),
            ),
          ),

          // Logs List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  )
                : filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0).withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_rounded,
                                  size: 40, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('actLogNoActivities'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('actLogTryFilter'),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) =>
                            _buildLogItem(filteredLogs[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedFilter = value;
          });
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color:
                isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLogItem(ActivityLogEntry log) {
    final style = _getActionStyle(log.actionType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (style['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              image: log.profilePhoto != null
                  ? DecorationImage(
                      image: NetworkImage(log.profilePhoto!), fit: BoxFit.cover)
                  : null,
            ),
            child: log.profilePhoto == null
                ? Icon(style['icon'] as IconData,
                    color: style['color'] as Color, size: 22)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (log.userRole.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getRoleColor(log.userRole).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          log.userRole.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            color: _getRoleColor(log.userRole),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (log.actorName.isNotEmpty)
                  Text(
                    _buildActorText(log),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500),
                  )
                else if (log.details.isNotEmpty)
                  Text(
                    log.details,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500),
                  ),
                const SizedBox(height: 8),
                Text(
                  _formatTime(log.timestamp),
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (style['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              log.actionType,
              style: TextStyle(
                color: style['color'] as Color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildActorText(ActivityLogEntry log) {
    switch (log.actionType.toUpperCase()) {
      case 'JOINED':
        return tr('actLogJoined', {'role': log.userRole});
      case 'ACCEPTED':
        return tr('actLogAccepted', {'actor': log.actorName});
      case 'REJECTED':
        return tr('actLogRejected', {'actor': log.actorName});
      case 'KICKED':
        return tr('actLogKicked', {'actor': log.actorName});
      case 'BLOCKED':
        return tr('actLogBlocked', {'actor': log.actorName});
      case 'UNBLOCKED':
        return tr('actLogUnblocked', {'actor': log.actorName});
      default:
        return log.details;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFF1E293B);
      case 'admin':
        return const Color(0xFF2563EB);
      case 'teacher':
        return const Color(0xFF10B981);
      case 'student':
        return const Color(0xFF0284C7);
      case 'staff':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  Map<String, dynamic> _getActionStyle(String type) {
    switch (type.toUpperCase()) {
      case 'JOINED':
      case 'ACCEPTED':
        return {
          'color': const Color(0xFF10B981),
          'icon': Icons.person_add_rounded
        };
      case 'REJECTED':
        return {'color': const Color(0xFFF59E0B), 'icon': Icons.cancel_rounded};
      case 'KICKED':
        return {
          'color': const Color(0xFFEF4444),
          'icon': Icons.remove_circle_outline_rounded
        };
      case 'BLOCKED':
        return {'color': const Color(0xFFEA580C), 'icon': Icons.block_rounded};
      case 'UNBLOCKED':
        return {
          'color': const Color(0xFF14B8A6),
          'icon': Icons.lock_open_rounded
        };
      default:
        return {
          'color': const Color(0xFF64748B),
          'icon': Icons.info_outline_rounded
        };
    }
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inDays == 0) {
        return tr('actLogToday', {'time': DateFormat('hh:mm a').format(dt)});
      } else if (difference.inDays == 1) {
        return tr('actLogYesterday', {'time': DateFormat('hh:mm a').format(dt)});
      } else if (difference.inDays < 7) {
        return tr('actLogDaysAgo', {'days': '${difference.inDays}'});
      } else {
        return DateFormat('dd MMM yyyy | hh:mm a').format(dt);
      }
    } catch (e) {
      return timestamp;
    }
  }
}
