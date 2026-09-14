import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/storage.dart';
import '../../../core/sign.dart';
import '../../../core/constants.dart';
import '../../../services/institution/directory_service.dart';
import '../../../chatting_platform/contact_profile_screen.dart';
import '../../../l10n/strings.dart';

class UserMember {
  final String id;
  final String name;
  final String? fatherName;
  final String? phone;
  final String email;
  final String? pfp;
  final String status;
  final String joinedDate;
  final String roleId;

  UserMember({
    required this.id,
    required this.name,
    this.fatherName,
    this.phone,
    required this.email,
    this.pfp,
    required this.status,
    required this.joinedDate,
    required this.roleId,
  });

  factory UserMember.fromJson(Map<String, dynamic> json) {
    return UserMember(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      fatherName: json['father_name'],
      phone: json['phone'],
      email: json['email'] ?? '',
      pfp: json['pfp'],
      status: json['status'] ?? 'active',
      joinedDate: json['joined_date'] ?? '',
      roleId: json['role_id'] ?? json['role'] ?? 'user',
    );
  }

  UserMember copyWith({String? pfp}) {
    return UserMember(
      id: id,
      name: name,
      fatherName: fatherName,
      phone: phone,
      email: email,
      pfp: pfp ?? this.pfp,
      status: status,
      joinedDate: joinedDate,
      roleId: roleId,
    );
  }
}

class RolesListScreen extends StatefulWidget {
  final String role; // 'admins' | 'teachers' | 'students' | 'staff'
  final VoidCallback onClose;

  const RolesListScreen({super.key, required this.role, required this.onClose});

  @override
  State<RolesListScreen> createState() => _RolesListScreenState();
}

class _RolesListScreenState extends State<RolesListScreen> {
  List<UserMember> users = [];
  List<UserMember> filteredUsers = [];
  bool isLoading = true;
  bool isOwner = false;
  final TextEditingController _searchController = TextEditingController();
  final DirectoryService _directoryService = DirectoryService();

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _fetchUsers();
  }

  Future<void> _checkUserRole() async {
    final role = await StarlightStorage.getUserRole();
    if (mounted) {
      setState(() {
        isOwner = role == 'owner';
      });
    }
  }

  Future<void> _fetchUsers() async {
    final token = await StarlightStorage.getUserToken();
    try {
      final response = await http.get(
        Uri.parse(
            "${StarlightConstants.directoryMembersEndpoint}?role=${widget.role}"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          users = data.map((u) => UserMember.fromJson(u)).toList();
          filteredUsers = users;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Directory Fetch Error: $e");
      _loadMockData();
    }
    _loadProfilePictures();
  }

  Future<void> _loadProfilePictures() async {
    final String base = StarlightConstants.apiBaseUrl;
    for (final u in List<UserMember>.from(users)) {
      try {
        final String pfpUrl = "$base/explore/pfp/user/${u.id}";
        final res = await http
            .get(Uri.parse(pfpUrl))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          if (mounted) {
            setState(() {
              users = users
                  .map((x) => x.id == u.id ? x.copyWith(pfp: pfpUrl) : x)
                  .toList();
              filteredUsers = filteredUsers
                  .map((x) => x.id == u.id ? x.copyWith(pfp: pfpUrl) : x)
                  .toList();
            });
          }
        }
      } catch (_) {}
    }
  }

  void _loadMockData() {
    setState(() {
      users = [
        UserMember(
            id: "101",
            name: "Abbass Ali",
            fatherName: "Mukhtar Ahmad",
            email: "abbass@starlight.pk",
            status: "active",
            joinedDate: "2026-01-01",
            roleId: widget.role == 'admins'
                ? 'owner'
                : widget.role.substring(0, widget.role.length - 1)),
        UserMember(
            id: "205",
            name: "Zahid Khan",
            fatherName: "Khan Wali",
            email: "zahid@starlight.pk",
            status: "active",
            joinedDate: "2026-02-15",
            roleId: widget.role == 'admins'
                ? 'owner'
                : widget.role.substring(0, widget.role.length - 1)),
      ];
      filteredUsers = users;
      isLoading = false;
    });
  }

  void _runSearch(String query) {
    setState(() {
      filteredUsers = users
          .where((u) =>
              u.name.toLowerCase().contains(query.toLowerCase()) ||
              u.id.contains(query))
          .toList();
    });
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
          tr('rolesDirTitle', {'role': widget.role.toUpperCase()}),
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
          // Header Banner matching your Vault layout style
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
                            tr('rolesDirVault'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tr('rolesManage', {'role': widget.role}),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('rolesDesc'),
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
                      Icons.supervised_user_circle_rounded,
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
            child: TextField(
              controller: _searchController,
              onChanged: _runSearch,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                hintText: tr('rolesSearchHint'),
                hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF2563EB), size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) =>
                        _buildUserCard(filteredUsers[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockDialog(UserMember user) async {
    if (user.roleId.toLowerCase() == 'owner' || widget.role == 'admins') {
      StarlightUtils.showErrorBox(context, tr('rolesCantBlockOwner'));
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('rolesBlockUser'),
            style:
                TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('rolesBlockConfirm', {'name': user.name})),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: tr('rolesBlockReason'),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('rolesCancel'),
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              await _blockUser(user, reasonController.text);
            },
            child: Text(tr('rolesBlockBtn'),
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(UserMember user, String reason) async {
    if (user.roleId.toLowerCase() == 'owner' || widget.role == 'admins') {
      StarlightUtils.showErrorBox(context, tr('rolesCantBlockOwner'));
      return;
    }

    try {
      StarlightUtils.showSuccessBox(context, tr('rolesBlocking', {'name': user.name}));
      await _directoryService.blockUser(user.id,
          reason: reason.isNotEmpty ? reason : null);
      if (mounted) {
        StarlightUtils.showSuccessBox(context, tr('rolesBlockedMsg', {'name': user.name}));
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(
            context, tr('rolesBlockFailed', {'error': e.toString()}));
      }
    }
  }

  Future<void> _showKickDialog(UserMember user) async {
    if (user.roleId.toLowerCase() == 'owner' || widget.role == 'admins') {
      StarlightUtils.showErrorBox(context, tr('rolesCantKickOwner'));
      return;
    }

    final TextEditingController reasonController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('rolesKickUser'),
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('rolesKickConfirm', {'name': user.name})),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: tr('rolesKickReason'),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('rolesCancel'),
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(context);
              await _kickUser(user, reasonController.text);
            },
            child: Text(tr('rolesKickBtn'),
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _kickUser(UserMember user, String reason) async {
    if (user.roleId.toLowerCase() == 'owner' || widget.role == 'admins') {
      StarlightUtils.showErrorBox(context, tr('rolesCantKickOwner'));
      return;
    }

    try {
      StarlightUtils.showSuccessBox(context, tr('rolesRemoving', {'name': user.name}));
      await _directoryService.kickUser(user.id,
          reason: reason.isNotEmpty ? reason : null);
      if (mounted) {
        StarlightUtils.showSuccessBox(context, tr('rolesKickedMsg', {'name': user.name}));
        _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showErrorBox(
            context, tr('rolesRemoveFailed', {'error': e.toString()}));
      }
    }
  }

  void _openUser(UserMember user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactProfileScreen(
          friendId: user.id,
          friendName: user.name,
          friendPhone: user.phone,
          friendProfilePicture: user.pfp,
        ),
      ),
    );
  }

  Widget _buildUserCard(UserMember user) {
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
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openUser(user),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      image: user.pfp != null
                          ? DecorationImage(
                              image: NetworkImage(user.pfp!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: user.pfp == null
                        ? const Icon(Icons.person_rounded,
                            color: Colors.white, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.fatherName ?? user.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwner &&
              widget.role != 'admins' &&
              user.roleId.toLowerCase() != 'owner')
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.block_rounded,
                      color: Colors.orange, size: 20),
                  tooltip: tr('rolesBlockUser'),
                  onPressed: () => _showBlockDialog(user),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: Colors.red, size: 20),
                  tooltip: tr('rolesKickUser'),
                  onPressed: () => _showKickDialog(user),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: () => _openUser(user),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }
}
