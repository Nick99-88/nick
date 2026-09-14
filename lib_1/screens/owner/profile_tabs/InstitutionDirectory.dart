import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../../core/sign.dart';
import '../../../core/storage.dart';
import '../../../core/constants.dart';
import 'ActivityLogs.dart';
import 'BlockedList.dart';
import 'RolesList.dart';
import 'verify_identities_screen.dart';
import 'LimitedAccessScreen.dart';
import 'InstitutionalTimingScreen.dart';
import 'link_identities_screen.dart';
import 'institution_leaderboard_screen.dart';
import '../../../library_management/screens/dashboard_screen.dart';
import '../../../library_management/services/sqlite_service.dart';

class InstitutionDirectoryScreen extends StatefulWidget {
  final VoidCallback onBack;
  const InstitutionDirectoryScreen({super.key, required this.onBack});

  @override
  State<InstitutionDirectoryScreen> createState() => _InstitutionDirectoryScreenState();
}

class _InstitutionDirectoryScreenState extends State<InstitutionDirectoryScreen> {
  Map<String, int> stats = {
    'admins': 0,
    'teachers': 0,
    'students': 0,
    'staff': 0,
    'blocked': 0
  };

  bool isLoading = true;
  String? referenceId;
  String? institutionName;
  String? institutionId;

  @override
  void initState() {
    super.initState();
    _loadDirectoryStats();
    _loadInstitutionDetails();
  }

  Future<void> _loadDirectoryStats() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse(StarlightConstants.directoryStatsEndpoint),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          stats = {
            'admins': data['admins'] ?? 0,
            'teachers': data['teachers'] ?? 0,
            'students': data['students'] ?? 0,
            'staff': data['staff'] ?? 0,
            'blocked': data['blocked'] ?? 0,
          };
          isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint("📡 API Error: $e");
    }

    if (mounted) {
      setState(() {
        stats = {
          'admins': 0,
          'teachers': 0,
          'students': 0,
          'staff': 0,
          'blocked': 0,
        };
        isLoading = false;
      });
    }
  }

  Future<void> _loadInstitutionDetails() async {
    try {
      final token = await StarlightStorage.getUserToken();
      final response = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/profile/institution-details"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            referenceId = data['reference_id'];
            institutionName = data['institution_name'];
            institutionId = data['institution_id'];
          });
        }
      }
    } catch (e) {
      debugPrint("📡 Institution details error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: widget.onBack,
          color: const Color(0xFF1A237E),
        ),
        title: Text(tr('instDirTitle'),
          style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                if (referenceId != null) _buildReferenceCard(),
                _buildStatsGrid(),
                _buildActionList(),
              ],
            ),
          ),
    );
  }

  Widget _buildReferenceCard() {
    final ref = referenceId!.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.tag, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(tr('instDirRef'), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ref,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace'),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: ref));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('instDirRefCopied', {'ref': ref})), duration: const Duration(seconds: 1)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Share.share('Join ${institutionName ?? "our institution"} on Starlight Institution\nREF: $ref\nhttps://institution.site/i/$institutionId');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.2,
        children: [
          _directoryCard(tr('instDirAdmins'), stats['admins']!, Icons.admin_panel_settings_rounded, Colors.blue, 'admins'),
          _directoryCard(tr('statTeachers'), stats['teachers']!, Icons.school_rounded, Colors.green, 'teachers'),
          _directoryCard(tr('statStudents'), stats['students']!, Icons.face_rounded, Colors.orange, 'students'),
          _directoryCard(tr('statStaff'), stats['staff']!, Icons.badge_rounded, Colors.purple, 'staff'),
        ],
      ),
    );
  }

  Widget _directoryCard(String label, int count, IconData icon, Color color, String role) {
    return InkWell(
      onTap: () => _openRole(role),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text("$count", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _actionItem(Icons.history_toggle_off_rounded, tr('instDirActivityLogs'), tr('instDirActivityLogsSub'), Colors.blueGrey, 'activityLogs'),
          _actionItem(Icons.schedule, tr('instDirTiming'), tr('instDirTimingSub'), Colors.green, 'timing'),
          _actionItem(Icons.block_flipped, tr('instDirBlocked'), tr('instDirBlockedSub', {'count': '${stats['blocked']}'}), Colors.red, 'blocked'),
          _actionItem(Icons.verified_user_rounded, tr('instDirVerify'), tr('instDirVerifySub'), Colors.teal, 'verify'),
          _actionItem(Icons.link_rounded, tr('instDirLink'), tr('instDirLinkSub'), Colors.indigo, 'link'),
          _actionItem(Icons.security_rounded, tr('instDirLimited'), tr('instDirLimitedSub'), Colors.amber, 'limited'),
          _actionItem(Icons.leaderboard_rounded, tr('instDirLeaderboard'), tr('instDirLeaderboardSub'), Colors.deepOrange, 'leaderboard'),
          _actionItem(Icons.local_library_rounded, tr('instDirLibrary'), tr('instDirLibrarySub'), Colors.brown, 'library'),
        ],
      ),
    );
  }

  Widget _actionItem(IconData icon, String title, String sub, Color color, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
        onTap: () async {
          switch (id) {
            case 'activityLogs':
              Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityLogsScreen(onClose: () => Navigator.pop(context))));
              break;
            case 'timing':
              Navigator.push(context, MaterialPageRoute(builder: (context) => InstitutionalTimingScreen(onClose: () => Navigator.pop(context))));
              break;
            case 'blocked':
              Navigator.push(context, MaterialPageRoute(builder: (context) => BlockedListScreen(onClose: () => Navigator.pop(context))));
              break;
            case 'verify':
              Navigator.push(context, MaterialPageRoute(builder: (context) => VerifyIdentitiesScreen(onClose: () => Navigator.pop(context))));
              break;
            case 'link':
              Navigator.push(context, MaterialPageRoute(builder: (context) => LinkIdentitiesScreen(onClose: () => Navigator.pop(context))));
              break;
            case 'limited':
              Navigator.push(context, MaterialPageRoute(builder: (context) => LimitedAccessScreen(onClose: () => Navigator.pop(context))));
              break;
            case 'leaderboard':
              Navigator.push(context, MaterialPageRoute(builder: (context) => InstitutionLeaderboardScreen(onClose: () => Navigator.pop(context))));
              break;
            case 'library':
              try {
                debugPrint('LibraryManagement: Starting SqliteService...');
                final service = SqliteService();
                debugPrint('LibraryManagement: Calling initialize()...');
                await service.initialize();
                debugPrint('LibraryManagement: Initialize done, navigating...');
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DashboardScreen(service: service)));
                  debugPrint('LibraryManagement: Navigation pushed.');
                }
              } catch (e, stack) {
                debugPrint('LibraryManagement: ERROR - $e');
                debugPrint('LibraryManagement: STACK - $stack');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                }
              }
              break;
            default:
              StarlightUtils.showSuccessBox(context, tr('instDirOpening', {'title': title}));
          }
        },
      ),
    );
  }

  void _openRole(String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RolesListScreen(
          role: role,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
