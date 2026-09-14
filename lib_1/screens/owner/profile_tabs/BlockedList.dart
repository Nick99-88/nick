import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/storage.dart';
import '../../../core/sign.dart';
import '../../../services/institution/directory_service.dart';

class BlockedUser {
  final String id;
  final String name;
  final String roleId;
  final String? reason;
  final String date;
  final String? pfp;

  BlockedUser({
    required this.id,
    required this.name,
    required this.roleId,
    this.reason,
    required this.date,
    this.pfp,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown User',
      roleId: json['role_id'] ?? 'User',
      reason: json['reason'],
      date: json['blocked_date'] ?? '',
      pfp: json['pfp'],
    );
  }
}

class BlockedListScreen extends StatefulWidget {
  final VoidCallback onClose;
  const BlockedListScreen({super.key, required this.onClose});

  @override
  State<BlockedListScreen> createState() => _BlockedListScreenState();
}

class _BlockedListScreenState extends State<BlockedListScreen> {
  final DirectoryService _directoryService = DirectoryService();
  List<BlockedUser> blockedUsers = [];
  List<BlockedUser> filteredUsers = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBlocked();
  }

  Future<void> _fetchBlocked() async {
    try {
      final data = await _directoryService.getBlockedUsers();
      setState(() {
        blockedUsers = data.map((u) => BlockedUser.fromJson(u)).toList();
        filteredUsers = blockedUsers;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Blocked List Error: $e");
      _loadMockData();
    }
  }

  void _loadMockData() {
    setState(() {
      blockedUsers = [
        BlockedUser(
            id: "502",
            name: "Haris Khan",
            roleId: "Student",
            reason: "Policy Violation",
            date: "2026-04-10"),
        BlockedUser(
            id: "901",
            name: "M. Ali",
            roleId: "Teacher",
            reason: "Security Breach",
            date: "2026-04-20"),
      ];
      filteredUsers = blockedUsers;
      isLoading = false;
    });
  }

  void _filterSearch(String query) {
    setState(() {
      filteredUsers = blockedUsers
          .where((u) =>
              u.name.toLowerCase().contains(query.toLowerCase()) ||
              u.id.contains(query))
          .toList();
    });
  }

  Future<void> _unblockUser(String id) async {
    // Replaced alerts with standard notification or snackbar system if needed,
    // but preserving the custom StarlightUtils or standard visual feedback mechanism.
    try {
      await _directoryService.unblockUser(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User Unblocked Successfully"),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _fetchBlocked();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Action Failed"),
            backgroundColor: Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
        title: const Text(
          "BLOCKED ACCOUNTS",
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Banner matching the Activity Logs theme style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF991B1B),
                    Color(0xFFDC2626),
                    Color(0xFFEF4444)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
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
                          child: const Text(
                            "RESTRICTED ACCESS",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Blocked Users Console",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Manage restricted accounts and lift security bans instantly.",
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
                      Icons.block_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search Field Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterSearch,
                decoration: InputDecoration(
                  hintText: "Search by name or ID...",
                  hintStyle:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // List Content
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                    ),
                  )
                : filteredUsers.isEmpty
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
                              child: const Icon(Icons.verified_user_rounded,
                                  size: 40, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No blocked accounts",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "All institution members are currently active.",
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) =>
                            _buildBlockedCard(filteredUsers[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedCard(BlockedUser user) {
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              image: user.pfp != null
                  ? DecorationImage(
                      image: NetworkImage(user.pfp!), fit: BoxFit.cover)
                  : null,
            ),
            child: user.pfp == null
                ? const Icon(Icons.person_off_rounded,
                    color: Color(0xFFEF4444), size: 22)
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
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.roleId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user.roleId.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.reason ?? "No reason provided",
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500),
                ),
                if (user.date.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Blocked on: ${user.date}",
                    style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _unblockUser(user.id),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "UNBLOCK",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
