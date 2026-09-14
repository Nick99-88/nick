import 'package:flutter/material.dart';
import '../../services/social/student_explore_service.dart';
import '../../services/social/student_friend_service.dart';
import '../../core/theme.dart';
import '../../widgets/profile_avatar.dart';
import 'full_profile_screen.dart';
import 'chat_screen.dart';
import 'student_map_screen.dart';
import 'dart:async';

class StudentExploreScreen extends StatefulWidget {
  const StudentExploreScreen({super.key});

  @override
  State<StudentExploreScreen> createState() => _StudentExploreScreenState();
}

class _StudentExploreScreenState extends State<StudentExploreScreen> {
  final StudentExploreService _exploreService = StudentExploreService();
  final StudentFriendService _friendService = StudentFriendService();
  final TextEditingController _searchController = TextEditingController();

  bool _isUserTab = true;
  List<dynamic> _students = [];
  bool _isLoading = true;
  Timer? _debounce;
  Map<String, dynamic> _userInfo = {};

  @override
  void initState() {
    super.initState();
    _searchStudents("");
  }

  void _searchStudents(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (mounted) {
        try {
          final results = await _exploreService.searchStudents(query);
          setState(() {
            _students = results['students'] ?? [];
            _userInfo = results['user_institution_info'] ?? {};
            _isLoading = false;
          });
        } catch (e) {
          setState(() => _isLoading = false);
          _showError(e.toString().replaceFirst('Exception: ', ''));
        }
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _navigateToProfile(dynamic student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullProfileScreen(
          item: student,
          isUser: true,
          hasInstitution: false,
        ),
      ),
    );
  }

  void _handleChatAction(dynamic student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          friendId: student['id'].toString(),
          friendName: student['name'] ?? 'Student',
          friendRole: 'student',
          friendPublicId: student['shortId']?.toString(),
          fromInbox: false,
        ),
      ),
    );
  }

  Future<void> _handleAddAction(dynamic student) async {
    final receiverId = student['id'].toString();
    try {
      await _friendService.sendStudentRequest(receiverId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Friend request sent to ${student['name']}!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: TextField(
          controller: _searchController,
          onChanged: _searchStudents,
          decoration: InputDecoration(
            hintText: "Search individual students...",
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _searchStudents("");
                    },
                    child: const Icon(Icons.close, size: 20),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildMapButton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentMapScreen()),
                  );
                },
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text("Map View", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.person, color: StarlightTheme.primaryBlue, size: 16),
            const SizedBox(width: 6),
            Text(
              "${_students.length} individual students found",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSearchBar(),
          _buildMapButton(),
          _buildStatsBar(),
          _buildResultsList(),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }

    if (_students.isEmpty) {
return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text("No individual students found", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              const Text("Try a different search or use Map View", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final student = _students[index];
            return _buildStudentCard(student);
          },
          childCount: _students.length,
        ),
      ),
    );
  }

  Widget _buildStudentCard(dynamic student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ProfileAvatar(
          userId: student['id']?.toString() ?? '',
          name: student['name'] ?? 'Student',
          radius: 24,
        ),
        title: Text(
          student['name'] ?? 'Unknown Student',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          "Individual Student • ${student['shortId'] ?? ''}",
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIconButton(Icons.chat_bubble_outline_rounded, () => _handleChatAction(student)),
            const SizedBox(width: 4),
            _buildIconButton(Icons.person_add_alt_1_rounded, () => _handleAddAction(student)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: StarlightTheme.primaryBlue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        icon: Icon(icon, color: StarlightTheme.primaryBlue, size: 20),
        onPressed: onTap,
        splashRadius: 20,
      ),
    );
  }
}