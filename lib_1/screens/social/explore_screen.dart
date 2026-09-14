import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../../services/social/explore_service.dart';
import '../../services/social/friend_request_service.dart';
import '../../services/fcm_service.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../widgets/profile_avatar.dart';
import '../../core/utils.dart';
import 'widgets/user_card.dart';
import 'widgets/institution_card.dart';
import 'full_profile_screen.dart';
import 'map_users_screen.dart';
import '../teacher/main_teacher_screen.dart';
import '../student/main_student_screen.dart';
import '../staff/staff_main_screen.dart';
import 'dart:async';
import 'chat_screen.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, this.initialRole = ''});

  final String initialRole;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final ExploreService _exploreService = ExploreService();
  final TextEditingController _searchController = TextEditingController();

  bool _isUserTab = true;
  List<dynamic> _users = [];
  List<dynamic> _institutions = [];
  bool _isLoading = true;
  Timer? _debounce;
  Map<String, dynamic> _userInstitutionInfo = {};

  String _selectedGender = '';
  String _selectedRole = '';
  String _selectedInstType = '';
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    _fetchInitialData();
    _registerFcmToken();
  }

  void _fetchInitialData() {
    _onSearchChanged("");
  }

  Future<void> _registerFcmToken() async {
    try {
      final localToken = await StarlightStorage.getLastFcmToken();
      if (localToken == null || localToken.isEmpty) {
        debugPrint("🔍 Explore: No local FCM token, skipping sync.");
        return;
      }

      final authToken = await StarlightStorage.getUserToken();
      if (authToken == null) return;

      final response = await http.patch(
        Uri.parse('${StarlightConstants.apiBaseUrl}/auth/update-fcm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({"fcm_token": localToken}),
      );

      if (response.statusCode == 200) {
        debugPrint("✅ Explore: FCM Token Synced with cloud.");
      }
    } catch (e) {
      debugPrint("🔍 Explore: FCM Sync Failure: $e");
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (mounted) {
        try {
          final results = await _exploreService.search(
            query,
            gender: _selectedGender,
            role: _selectedRole,
            instType: _selectedInstType,
          );
          setState(() {
            _users = results['users'] ?? [];
            _institutions = results['institutions'] ?? [];
            _userInstitutionInfo = results['user_institution_info'] ?? {};
            _isLoading = false;
          });
        } catch (e) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error loading data: ${e.toString()}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void _applyFilters() {
    _onSearchChanged(_searchController.text);
    setState(() => _showFilters = false);
  }

  void _clearFilters() {
    setState(() {
      _selectedGender = '';
      _selectedRole = '';
      _selectedInstType = '';
    });
    _onSearchChanged(_searchController.text);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _navigateToProfile(dynamic item, bool isUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullProfileScreen(
          item: item,
          isUser: isUser,
          hasInstitution: _userInstitutionInfo['has_institution'] == true,
        ),
      ),
    );
  }

  void _handleChatAction(dynamic user) {
    final friendId = user['id'].toString();
    final friendName = user['name']?.toString() ?? '';
    final friendRole = user['role']?.toString() ?? '';
    final friendPhone = user['phone']?.toString();
    final friendProfilePicture = user['profile_picture']?.toString();
    final friendPublicId = user['public_id']?.toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          friendId: friendId,
          friendName: friendName,
          friendRole: friendRole,
          friendPhone: friendPhone,
          friendProfilePicture: friendProfilePicture,
          friendPublicId: friendPublicId,
          fromInbox: false,
        ),
      ),
    );
  }

  void _handleAddAction(dynamic user) async {
    final receiverId = user['id'].toString();
    try {
      final service = FriendRequestService();
      await service.sendRequest(receiverId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Request sent to ${user['name']}!"),
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

  Widget _buildDashboardButton() {
    final userRole = _userInstitutionInfo['user_role']?.toString().toLowerCase() ?? '';

    if (userRole.contains('owner')) {
      return const SizedBox.shrink();
    }

    String buttonText = 'Dashboard';
    VoidCallback onPressed = () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Dashboard coming soon for $userRole role!"),
          backgroundColor: Colors.blue,
        ),
      );
    };

    if (userRole.contains('teacher') || userRole.contains('admin')) {
      buttonText = 'Teacher Dashboard';
      onPressed = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainTeacherScreen(),
          ),
        );
      };
    } else if (userRole.contains('student')) {
      buttonText = 'Student Dashboard';
      onPressed = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainStudentScreen(),
          ),
        );
      };
    } else if (userRole.contains('staff')) {
      buttonText = 'Staff Dashboard';
      onPressed = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StaffMainScreen(),
          ),
        );
      };
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.dashboard, size: 18),
        label: Text(buttonText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: userRole.contains('teacher') || userRole.contains('admin')
              ? Colors.orange
              : Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSearchBar(),
          _buildTabPicker(),
          _buildResultsGrid(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      icon: const Icon(Icons.search),
                      hintText: _isUserTab
                          ? "Search by name, ID, REF, institution..."
                          : "Search institutions by name, REF, type...",
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _onSearchChanged("");
                              },
                              child: const Icon(Icons.close, size: 20),
                            ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _showFilters = !_showFilters),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (_selectedGender.isNotEmpty || _selectedRole.isNotEmpty || _selectedInstType.isNotEmpty)
                                    ? const Color(0xFF1A237E).withOpacity(0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.tune,
                                size: 20,
                                color: (_selectedGender.isNotEmpty || _selectedRole.isNotEmpty || _selectedInstType.isNotEmpty)
                                    ? const Color(0xFF1A237E)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_showFilters) _buildFilterPanel(),
            if (_selectedGender.isNotEmpty || _selectedRole.isNotEmpty || _selectedInstType.isNotEmpty)
              _buildActiveFilters(),
            const SizedBox(height: 10),
            if (_userInstitutionInfo['has_institution'] == true) ...[
              _buildDashboardButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isUserTab) ...[
            const Text("Gender", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildFilterChips(
              ['Male', 'Female', 'Other'],
              _selectedGender,
              (val) => setState(() => _selectedGender = val == _selectedGender ? '' : val),
            ),
            const SizedBox(height: 16),
            const Text("Role", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildFilterChips(
              ['Student', 'Teacher', 'Staff', 'Admin', 'Owner'],
              _selectedRole,
              (val) => setState(() => _selectedRole = val == _selectedRole ? '' : val),
            ),
          ] else ...[
            const Text("Institution Type", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildFilterChips(
              ['School', 'Academy', 'College'],
              _selectedInstType,
              (val) => setState(() => _selectedInstType = val == _selectedInstType ? '' : val),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Clear All"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Apply"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<String> options, String selected, Function(String) onTap) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.toLowerCase() == opt.toLowerCase();
        return GestureDetector(
          onTap: () => onTap(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1A237E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF1A237E) : Colors.grey.shade300,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (_selectedGender.isNotEmpty)
            _activeFilterChip(_selectedGender, () {
              setState(() => _selectedGender = '');
              _onSearchChanged(_searchController.text);
            }),
          if (_selectedRole.isNotEmpty)
            _activeFilterChip(_selectedRole, () {
              setState(() => _selectedRole = '');
              _onSearchChanged(_searchController.text);
            }),
          if (_selectedInstType.isNotEmpty)
            _activeFilterChip(_selectedInstType, () {
              setState(() => _selectedInstType = '');
              _onSearchChanged(_searchController.text);
            }),
        ],
      ),
    );
  }

  Widget _activeFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF1A237E), fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Color(0xFF1A237E)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPicker() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _tabNode("USERS", _isUserTab, () => setState(() => _isUserTab = true)),
            const SizedBox(width: 15),
            _tabNode("INSTITUTIONS", !_isUserTab, () => setState(() => _isUserTab = false)),
            const SizedBox(width: 15),
            _tabNode("MAP", false, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapUsersScreen()),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _tabNode(String title, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A237E) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(color: isActive ? Colors.white : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildResultsGrid() {
    if (_isLoading) {
      return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
    }

    final results = _isUserTab ? _users : _institutions;

    if (results.isEmpty) {
      return const SliverFillRemaining(child: Center(child: Text("No results found")));
    }

    return SliverPadding(
      padding: const EdgeInsets.all(15),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = results[index];
            if (_isUserTab) {
              return UserCard(
                name: item['name'] ?? 'User',
                role: item['role'] ?? 'Student',
                id: item['id'].toString(),
                institution: item['institution'] as Map<String, dynamic>?,
                bio: item['bio']?.toString(),
                shortId: item['shortId']?.toString(),
                onTap: () => _navigateToProfile(item, true),
                onChat: () => _handleChatAction(item),
                onAdd: () => _handleAddAction(item),
              );
            } else {
              return InstitutionCard(
                name: item['name'] ?? 'Institution',
                ref: item['ref'] ?? 'N/A',
                type: item['type'] ?? 'institution',
                id: item['id'].toString(),
                ownerName: item['owner_name'],
                address: item['address']?.toString(),
                email: item['email']?.toString(),
                description: item['description']?.toString(),
                onTap: () => _navigateToProfile(item, false),
              );
            }
          },
          childCount: results.length,
        ),
      ),
    );
  }
}
