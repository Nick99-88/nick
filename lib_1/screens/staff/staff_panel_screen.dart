import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../owner/owner_console_screen.dart';
import '../owner/documents_screen.dart';
import '../owner/analytics/analytics_screen.dart';
import '../owner/profile_tabs/InstitutionDirectory.dart';

class StaffPanelScreen extends StatefulWidget {
  const StaffPanelScreen({super.key});

  @override
  State<StaffPanelScreen> createState() => _StaffPanelScreenState();
}

class _StaffPanelScreenState extends State<StaffPanelScreen> {
  Map<String, dynamic> _permissions = {};
  String _identityType = 'staff';
  String _designation = '';
  bool _isLoading = true;

  static const Map<String, Map<String, dynamic>> _moduleConfig = {
    'dashboard': {'label': 'Dashboard', 'icon': Icons.dashboard_rounded, 'color': 'blue'},
    'directory': {'label': 'Institutional Directory', 'icon': Icons.contacts_rounded, 'color': 'purple'},
    'documents': {'label': 'Institutional Documents', 'icon': Icons.folder_open_rounded, 'color': 'green'},
    'analysis': {'label': 'Institutional Analysis', 'icon': Icons.analytics_rounded, 'color': 'orange'},
  };

  static Color _colorFromName(String name) {
    switch (name) {
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'orange': return Colors.orange;
      case 'red': return Colors.redAccent;
      case 'purple': return Colors.purple;
      case 'indigo': return Colors.indigo;
      case 'teal': return Colors.teal;
      case 'brown': return Colors.brown;
      case 'cyan': return Colors.cyan;
      case 'pink': return Colors.pink;
      case 'amber': return Colors.amber.shade700;
      case 'blueGrey': return Colors.blueGrey;
      case 'deepPurple': return Colors.deepPurple;
      case 'lightBlue': return Colors.lightBlue;
      case 'deepOrange': return Colors.deepOrange;
      default: return StarlightTheme.primaryBlue;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCachedThenFetch();
  }

  Future<void> _loadCachedThenFetch() async {
    final cached = await StarlightStorage.getStaffAccessMap();
    if (cached != null && cached.containsKey('permissions')) {
      if (mounted) {
        setState(() {
          _permissions = Map<String, dynamic>.from(cached['permissions'] as Map? ?? {});
          _identityType = cached['identity_type'] as String? ?? 'staff';
          _designation = cached['entity_designation'] as String? ?? '';
          _isLoading = false;
        });
      }
    }
    _fetchPermissions();
  }

  Future<void> _fetchPermissions() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/staff/permissions"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await StarlightStorage.setStaffAccess(jsonEncode(data));
        if (mounted) {
          setState(() {
            _permissions = Map<String, dynamic>.from(data['permissions'] as Map? ?? {});
            _identityType = data['identity_type'] as String? ?? 'staff';
            _designation = data['entity_designation'] as String? ?? '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch permissions from server, using cached data: $e");
      if (mounted && _permissions.isEmpty) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _hasAccess(String module) {
    final perm = _permissions[module];
    if (perm == null) return false;
    if (perm is String) return perm != 'none';
    if (perm is bool) return perm;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          _designation.isNotEmpty ? _designation : "Access Panel",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            onPressed: _fetchPermissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final modules = _moduleConfig.entries
        .where((e) => _hasAccess(e.key))
        .toList();

    if (modules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text("No modules available", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPermissions,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: modules.length,
        itemBuilder: (_, index) {
          final entry = modules[index];
          final config = entry.value;
          final color = _colorFromName(config['color'] as String);
          return _moduleTile(
            label: config['label'] as String,
            icon: config['icon'] as IconData,
            color: color,
            onTap: () => _navigateToModule(entry.key),
          );
        },
      ),
    );
  }

  Widget _moduleTile({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _navigateToModule(String module) {
    switch (module) {
      case 'dashboard':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerConsoleScreen()));
      case 'directory':
        Navigator.push(context, MaterialPageRoute(builder: (_) => InstitutionDirectoryScreen(onBack: () => Navigator.pop(context))));
      case 'documents':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen()));
      case 'analysis':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$module module coming soon"), behavior: SnackBarBehavior.floating),
        );
    }
  }
}
