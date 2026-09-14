import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import '../../../core/sign.dart';
import '../../../core/storage.dart';
import '../../../core/constants.dart';

class LimitedAccessScreen extends StatefulWidget {
  final VoidCallback onClose;
  const LimitedAccessScreen({super.key, required this.onClose});

  @override
  State<LimitedAccessScreen> createState() => _LimitedAccessScreenState();
}

class _LimitedAccessScreenState extends State<LimitedAccessScreen> {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/institution/directory";
  final TextEditingController _searchController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool isLoading = true;
  List<Map<String, dynamic>> linkedUsers = [];
  String _filterType = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLinkedUsers();
  }

  Future<void> _loadLinkedUsers() async {
    setState(() => isLoading = true);
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse("$_baseUrl/linked-users"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          linkedUsers = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("Limited Access Error: $e");
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<bool> _authenticate() async {
    try {
      return await _localAuth.authenticate(localizedReason: "Authenticate to manage access permissions");
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var users = linkedUsers;
    if (_searchQuery.isNotEmpty) {
      users = users.where((u) {
        final name = (u['user_name'] ?? '').toString().toLowerCase();
        final email = (u['user_email'] ?? '').toString().toLowerCase();
        final identityName = (u['identity_name'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query) || identityName.contains(query);
      }).toList();
    }
    if (_filterType == 'with_permissions') return users.where((u) => u['permissions'] != null && (u['permissions'] as Map).isNotEmpty).toList();
    if (_filterType == 'without_permissions') return users.where((u) => u['permissions'] == null || (u['permissions'] as Map).isEmpty).toList();
    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: widget.onClose,
          color: const Color(0xFF263238),
        ),
        title: const Text("LIMITED ACCESS",
            style: TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStats(),
                _buildSearchBar(),
                _buildFilters(),
                const Divider(height: 1),
                Expanded(child: _buildUsersList()),
              ],
            ),
    );
  }

  Widget _buildStats() {
    final total = linkedUsers.length;
    final withPerms = linkedUsers.where((u) => u['permissions'] != null && (u['permissions'] as Map).isNotEmpty).length;
    final withoutPerms = total - withPerms;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _statChip("$total", "Linked", Colors.green),
          const SizedBox(width: 8),
          _statChip("$withPerms", "Configured", Colors.purple),
          const SizedBox(width: 8),
          _statChip("$withoutPerms", "No Access Set", Colors.orange),
        ],
      ),
    );
  }

  Widget _statChip(String count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search by name, email, or identity...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('All', 'all'),
            _filterChip('With Permissions', 'with_permissions'),
            _filterChip('Without Permissions', 'without_permissions'),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filterType == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.grey[700])),
        selected: isSelected,
        onSelected: (selected) => setState(() => _filterType = value),
        selectedColor: const Color(0xFF263238),
        backgroundColor: Colors.grey[100],
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildUsersList() {
    final users = _filteredUsers;
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No users found", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) => _userCard(users[index]),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final identityType = user['identity_type'];
    final hasPermissions = user['permissions'] != null && (user['permissions'] as Map).isNotEmpty;
    final typeColor = _getTypeColor(identityType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final authed = await _authenticate();
          if (authed) _showPermissionsDialog(user);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: typeColor.withOpacity(0.15),
                child: Text(
                  (user['user_name'] ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: typeColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['user_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(user['user_email'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(identityType.toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: typeColor)),
                        ),
                        const SizedBox(width: 6),
                        Text(user['identity_name'] ?? '',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    hasPermissions ? Icons.security : Icons.lock_open,
                    color: hasPermissions ? Colors.green : Colors.grey[400],
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasPermissions ? "Configured" : "No Access Set",
                    style: TextStyle(
                      fontSize: 9,
                      color: hasPermissions ? Colors.green : Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'student':
        return Colors.orange;
      case 'teacher':
        return Colors.purple;
      case 'staff':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _showPermissionsDialog(Map<String, dynamic> user) {
    final permissions = Map<String, dynamic>.from(user['permissions'] ?? {});

    final modules = [
      {'key': 'dashboard', 'label': 'Dashboard', 'icon': Icons.dashboard},
      {'key': 'directory', 'label': 'Institutional Directory', 'icon': Icons.contacts},
      {'key': 'documents', 'label': 'Institutional Documents', 'icon': Icons.folder_open},
      {'key': 'analysis', 'label': 'Institutional Analysis', 'icon': Icons.analytics},
    ];

    final levels = ['full', 'write', 'read', 'none'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Access: ${user['user_name']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Linked as ${user['identity_type']} — ${user['identity_name']}",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final mod = modules[index];
                final currentLevel = permissions[mod['key']] ?? 'none';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(mod['icon'] as IconData, size: 20, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(mod['label'] as String,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: _getLevelColor(currentLevel).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: currentLevel,
                            isDense: true,
                            style: TextStyle(fontSize: 12, color: _getLevelColor(currentLevel), fontWeight: FontWeight.bold),
                            items: levels
                                .map((l) => DropdownMenuItem(value: l, child: Text(l.toUpperCase())))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => permissions[mod['key'] as String] = value!);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _savePermissions(user['identity_id'], permissions);
                Navigator.pop(context);
                _loadLinkedUsers();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF263238)),
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'full':
        return Colors.green;
      case 'write':
        return Colors.blue;
      case 'read':
        return Colors.orange;
      case 'none':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _savePermissions(String identityId, Map<String, dynamic> permissions) async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.put(
        Uri.parse("$_baseUrl/permissions/$identityId"),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'permissions': permissions}),
      );

      if (response.statusCode == 200 && mounted) {
        StarlightUtils.showSuccessBox(context, "Permissions saved!");
      }
    } catch (e) {
      if (mounted) StarlightUtils.showErrorBox(context, e.toString());
    }
  }
}
