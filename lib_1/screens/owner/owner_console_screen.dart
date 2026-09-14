import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/socket_vault.dart';
import '../../core/ads_setup.dart';
import '../../core/ad_service.dart';
import 'tabs/section_list_screen.dart';
import 'tabs/subject_list_screen.dart';
import 'tabs/role_list_screen.dart';
import 'tabs/staff_hiring_screen.dart';
import 'tabs/student_admission_screen.dart';
import 'tabs/teacher_hiring_screen.dart';
import '../../core/router_gateway.dart';
import '../../l10n/strings.dart';
import '../../shop/shop_screen.dart';
import 'tabs/database/dashboard_cache_service.dart';
import 'tabs/database/dashboard_sync_service.dart';

class OwnerConsoleScreen extends StatefulWidget {
  const OwnerConsoleScreen({super.key});

  @override
  State<OwnerConsoleScreen> createState() => _OwnerConsoleScreenState();
}

class _OwnerConsoleScreenState extends State<OwnerConsoleScreen> {
  String _userName = tr('loading');
  String _institutionName = "Starlight Institution";

  int _studentCount = 0;
  int _teacherCount = 0;
  int _staffCount = 0;
  int _subjectCount = 0;
  int _roleCount = 0;
  int _sectionCount = 0;

  bool _isRefreshing = false;
  int _pendingCount = 0;
  Timer? _pendingTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _loadIdentity();
    _fetchDashboardStats();
    _loadPendingCount();
    _preloadAds();
    DashboardSyncService.instance.onSyncComplete = (_) => _loadPendingCount();
    _pendingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadPendingCount());
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchDashboardStats();
    _loadIdentity();
    if (mounted) setState(() => _isRefreshing = false);
    _preloadAds();
  }

  void _preloadAds() {
    if (AdConfig.isInitialized && !AdService.instance.isRewardedAdReady) {
      AdService.instance.loadRewardedAd();
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final count = await DashboardCacheService.instance.getPendingOpCount();
      if (mounted) setState(() => _pendingCount = count);
    } catch (_) {}
  }

  Future<void> _storeLocally() async {
    setState(() => _isRefreshing = true);
    try {
      await DashboardSyncService.instance.syncPendingOps();
      await DashboardCacheService.instance.syncAll(forceRefresh: true);
      await _loadPendingCount();
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('allDataStoredLocally')), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('syncFailed', {'error': '$e'})), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _watchAd() async {
    if (!AdConfig.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('adEngineLoading')), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    if (!AdService.instance.isRewardedAdReady) {
      await AdService.instance.loadRewardedAd();
    }
    final reward = await AdService.instance.showRewardedAd(
      onRewarded: () async {
        final credits = await AdService.instance.creditRewardedAdUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.stars, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(tr('earnedCredits', {
                  'silver': '${credits['silver']}',
                  'aiCredits': '${credits['ai_credits']}',
                }), style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
    if (!reward && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('adNotCompleted')), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/dashboard/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _studentCount = data['student_count'] ?? 0;
            _teacherCount = data['teacher_count'] ?? 0;
            _staffCount = data['staff_count'] ?? 0;
            _subjectCount = data['total_subjects'] ?? 0;
            _roleCount = data['total_roles'] ?? 0;
            _sectionCount = data['total_sections'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint("🏛️ Dashboard Stats Error: $e");
    }
  }

  Future<void> _initializeDashboard() async {
    _syncFCMToken();
    _connectSocket(); // 🏛️ Ignition on load
    _loadPendingCount();
  }

  // 🏛️ The Real-Time Handshake (Fixed to use JWT Token)
  Future<void> _connectSocket() async {
    // 🏛️ Fetch the JWT token from storage
    final token = await StarlightStorage.getUserToken();

    // Only initialize if token exists and is valid
    if (token != null && token != "null" && token.isNotEmpty) {
      debugPrint("🏛️ System: Initializing Real-time Pipe with JWT...");
      await StarlightSocket().init(token);
    } else {
      debugPrint("🏛️ System: Socket Aborted - No valid session token found.");
    }
  }

  void _loadIdentity() async {
    final Map<String, String> cached = await StarlightStorage.getIIdentity();
    if (mounted) {
      setState(() {
        _userName = _titalize(cached['user'] ?? "Administrator");
        _institutionName =
            _titalize(cached['institution'] ?? "Starlight Institution");
      });
    }
  }

  String _titalize(String text) {
    if (text.isEmpty) return text;
    String cleanText = text.replaceAll('_', ' ');
    return cleanText.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _syncFCMToken() async {
    try {
      final localToken = await StarlightStorage.getLastFcmToken();
      if (localToken == null || localToken.isEmpty) {
        debugPrint("🏛️ FCM: No local token found, skipping sync.");
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
        debugPrint("✅ FCM Token Synced with cloud.");
      }
    } catch (e) {
      debugPrint("🏛️ FCM Sync Failure: $e");
    }
  }

  Future<void> _handleLogout() async {
    StarlightSocket().close(); // 🏛️ Sever connection
    await StarlightStorage.logout();
    if (mounted) {
      UniversalRouter.routeUser(context);
    }
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_institutionName.toUpperCase(),
                style: const TextStyle(
                    color: Color(0xFF1A237E),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
            Row(
              children: [
                const Icon(Icons.verified_user,
                    size: 10, color: StarlightTheme.primaryBlue),
                const SizedBox(width: 4),
                Text(_userName,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          StreamBuilder<bool>(
            stream: AdService.instance.onRewardedAdLoaded,
            initialData: AdService.instance.isRewardedAdReady,
            builder: (context, snapshot) {
              final ready = snapshot.data ?? false;
              return IconButton(
                icon: Icon(Icons.play_circle_outline, size: 22, color: ready ? Colors.green.shade600 : Colors.grey),
                onPressed: _watchAd,
                tooltip: ready ? tr('watchAdEarnRewards') : tr('loadingAd'),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.green, size: 22),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
            },
            tooltip: tr('shop'),
          ),
          const SizedBox(width: 8),
        ],
        shape: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1)),
      ),
      body: RefreshIndicator(
        color: StarlightTheme.primaryBlue,
        backgroundColor: Colors.white,
        strokeWidth: 2.5,
        onRefresh: _handleRefresh,
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(20),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickStats(),
              const SizedBox(height: 30),
              Text(tr('managementModules'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 12,
                      letterSpacing: 1.1)),
              const SizedBox(height: 15),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.1,
                children: [
                  _consoleButton("Admissions", tr('admissionsTitle'), tr('admissionsSub'),
                      Icons.person_add_alt_1_rounded, Colors.blue),
                  _consoleButton("Student Records", tr('studentRecordsTitle'), tr('studentRecordsSub'),
                      Icons.assignment_ind_rounded, Colors.orange),
                  _consoleButton("Teacher Hiring", tr('teacherHiringTitle'), tr('teacherHiringSub'),
                      Icons.co_present_rounded, Colors.green),
                  _consoleButton("Teacher Records", tr('teacherRecordsTitle'), tr('teacherRecordsSub'),
                      Icons.book_outlined, Colors.green),
                  _consoleButton("Staff Hiring", tr('staffHiringTitle'), tr('staffHiringSub'),
                      Icons.work_history_rounded, Colors.purple),
                  _consoleButton("Staff Records", tr('staffRecordsTitle'), tr('staffRecordsSub'),
                      Icons.badge_rounded, Colors.teal),
                ],
              ),
              const SizedBox(height: 25),
            ],
          ),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: Stack(
                children: [
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: StarlightTheme.primaryBlue,
                    onPressed: _isRefreshing ? null : _storeLocally,
                    child: _isRefreshing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 20),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _pendingCount > 0 ? Colors.red : Colors.grey[600]!,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [StarlightTheme.primaryBlue, Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: StarlightTheme.primaryBlue.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem(tr('statStudents'), _studentCount.toString(), Icons.school_outlined),
              _statItem(tr('statTeachers'), _teacherCount.toString(), Icons.badge_outlined),
              _statItem(tr('statStaff'), _staffCount.toString(), Icons.engineering_outlined),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem(tr('statSections'), _sectionCount.toString(), Icons.view_module_rounded),
              _statItem(tr('statSubjects'), _subjectCount.toString(), Icons.book_outlined),
              _statItem(tr('statRoles'), _roleCount.toString(), Icons.badge_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white60, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        Text(label.toUpperCase(),
            style: TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _consoleButton(String routeKey, String title, String sub, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        Widget? destination;
        switch (routeKey) {
          case "Admissions":
            destination = const StudentAdmissionScreen();
            break;
          case "Student Records":
            destination = const SectionManagementScreen();
            break;
          case "Teacher Records":
            destination = const SubjectManagementScreen();
            break;
          case "Teacher Hiring":
            destination = const TeacherHiringScreen();
            break;
          case "Staff Hiring":
            destination = const StaffHiringScreen();
            break;
          case "Staff Records":
            destination = const RoleManagementScreen();
            break;
        }
        if (destination != null) {
          Navigator.push(
              context, MaterialPageRoute(builder: (context) => destination!));
        }
      },
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF2D3142))),
            const SizedBox(height: 2),
            Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 8.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
