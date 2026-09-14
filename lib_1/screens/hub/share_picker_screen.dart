import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class SharePickerScreen extends StatefulWidget {
  final String category;
  final String title;
  final Map<String, dynamic> details;
  final String timestamp;
  final String? ownerId;
  final String? ownerName;

  const SharePickerScreen({
    super.key,
    required this.category,
    required this.title,
    required this.details,
    required this.timestamp,
    this.ownerId,
    this.ownerName,
  });

  @override
  State<SharePickerScreen> createState() => _SharePickerScreenState();
}

class _SharePickerScreenState extends State<SharePickerScreen> {
  List<Map<String, dynamic>> _users = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSending = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/share/all-users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          if (mounted) setState(() => _users = List<Map<String, dynamic>>.from(data));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final filtered = _users.where((u) {
      // Exclude the owner from the share picker (can't share with yourself)
      if (widget.ownerId != null && u['id']?.toString() == widget.ownerId) return false;
      return true;
    });
    if (_searchQuery.isEmpty) return filtered.toList();
    return filtered.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  Future<void> _confirmShare() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/share/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receiver_ids': _selectedIds.toList(),
          'category': widget.category,
          'title': widget.title,
          'details': widget.details,
          'timestamp': widget.timestamp,
        }),
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Document shared successfully"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to share document"), backgroundColor: Colors.red),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error"), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Share Document", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: StarlightTheme.primaryBlue,
        elevation: 0,
        actions: [
          if (_selectedIds.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text("${_selectedIds.length} selected",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: _isSending ? null : _confirmShare,
            tooltip: "Confirm Share",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Owner indicator
                if (widget.ownerName != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(Icons.person, size: 18, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Shared by you",
                                  style: TextStyle(fontSize: 11, color: Colors.blue.shade400)),
                              Text(widget.ownerName!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text("Owner",
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: Colors.white,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search users...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Expanded(
                  child: _filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text("No users found", style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (_, i) => _buildUserTile(_filteredUsers[i]),
                        ),
                ),
              ],
            ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isSending ? null : _confirmShare,
              backgroundColor: Colors.green,
              icon: _isSending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_isSending ? "Sharing..." : "Send to ${_selectedIds.length} user(s)"),
            )
          : null,
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final role = user['role'] ?? '';
    final isSelected = _selectedIds.contains(id);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.1)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedIds.remove(id);
              } else {
                _selectedIds.add(id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isSelected ? Colors.green.withOpacity(0.1) : StarlightTheme.primaryBlue.withOpacity(0.1),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.person,
                    color: isSelected ? Colors.green : StarlightTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (email.isNotEmpty)
                        Text(email, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    role,
                    style: TextStyle(fontSize: 9, color: isSelected ? Colors.green : Colors.grey[600]),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.green : Colors.grey[300],
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
