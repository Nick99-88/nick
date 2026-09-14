import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/constants.dart';
import '../../core/ads_setup.dart';
import '../../core/ad_service.dart';
import '../../shop/shop_screen.dart';
import '../../screens/hub/wallet_screen.dart';
import '../../video_directory/screens/video_directory.dart';
import '../../timetable_directory/screens/timetable_directory.dart';
import '../../qr_portal/qr_portal_screen.dart';
import '../../chat_system/chat_system_entry.dart' as chat_system;

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboard> {
  String _staffName = '';
  bool _isLoading = true;

  int _present = 0;
  int _absent = 0;
  int _totalAttendance = 0;

  final List<Map<String, dynamic>> _hubTiles = [
    {'icon': Icons.wallet, 'label': 'Wallet', 'screen': const WalletScreen(), 'color': Colors.teal},
    {'icon': Icons.video_library, 'label': 'Videos', 'screen': const VideoDirectory(), 'color': Colors.purple},
    {'icon': Icons.schedule, 'label': 'Timetable', 'screen': const TimetableDirectory(), 'color': Colors.indigo},
    {'icon': Icons.qr_code, 'label': 'QR Portal', 'screen': const QRPortalScreen(), 'color': Colors.blue},
    {'icon': Icons.chat, 'label': 'Chatting', 'screen': const chat_system.WhatsAppChatEntry(), 'color': Colors.green},
  ];
  List<Map<String, dynamic>> _randomTiles = [];

  @override
  void initState() {
    super.initState();
    _randomTiles = List.from(_hubTiles)..shuffle();
    _randomTiles = _randomTiles.take(4).toList();
    _loadData();
    _preloadAds();
  }

  void _preloadAds() {
    if (AdConfig.isInitialized && !AdService.instance.isRewardedAdReady) {
      AdService.instance.loadRewardedAd();
    }
  }

  Future<void> _watchAd() async {
    if (!AdConfig.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad engine still loading...'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
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
                Text('Earned ${credits['silver']} Silver + ${credits['ai_credits']} AI Credits!', style: const TextStyle(fontWeight: FontWeight.bold)),
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
        const SnackBar(content: Text('Ad not completed. Try again!'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _loadData() async {
    await _loadProfile();
    await _loadAttendance();

    final shuffled = List<Map<String, dynamic>>.from(_hubTiles)..shuffle();
    _randomTiles = shuffled.take(4).toList();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse("${StarlightConstants.apiBaseUrl}/profile/identity"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _staffName = data['full_name'] ?? data['name'] ?? 'Staff';
          });
        }
        await StarlightStorage.setUserName(_staffName);
      }
    } catch (_) {
      final cached = await StarlightStorage.getUserName();
      if (mounted) setState(() => _staffName = cached ?? 'Staff');
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/attendance/my-history'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['records'] != null) {
          final records = List<Map<String, dynamic>>.from(data['records']);
          if (mounted) {
            setState(() {
              _present = records.where((r) => r['status'] == 'present' || r['status'] == 'P').length;
              _absent = records.where((r) => r['status'] == 'absent' || r['status'] == 'A').length;
              _totalAttendance = records.length;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Welcome, $_staffName",
              style: const TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          StreamBuilder<bool>(
            stream: AdService.instance.onRewardedAdLoaded,
            initialData: AdService.instance.isRewardedAdReady,
            builder: (context, snapshot) {
              final ready = snapshot.data ?? false;
              return IconButton(
                icon: Icon(Icons.play_circle_outline, size: 22, color: ready ? Colors.green.shade600 : Colors.grey),
                onPressed: _watchAd,
                tooltip: ready ? "Watch Ad — Earn Rewards" : "Loading Ad...",
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
            tooltip: "Shop",
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildAdBanner(),
              const SizedBox(height: 16),
              _buildAttendanceCard(),
              const SizedBox(height: 16),
              _buildQuickAccessGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen())),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Sponsored", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                  SizedBox(height: 4),
                  Text("Check out latest deals\nand offers in the shop!",
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text("AD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final rate = _totalAttendance > 0 ? (_present / _totalAttendance * 100).toStringAsFixed(0) : '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note, color: StarlightTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              const Text("My Attendance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _attStat(Icons.check_circle, "$_present", "Present", Colors.green),
              const SizedBox(width: 8),
              _attStat(Icons.cancel, "$_absent", "Absent", Colors.redAccent),
              const SizedBox(width: 8),
              _attStat(Icons.analytics, "$rate%", "Rate", StarlightTheme.primaryBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Access", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: _randomTiles.length,
          itemBuilder: (_, i) {
            final tile = _randomTiles[i];
            return _buildTile(
              icon: tile['icon'] as IconData,
              label: tile['label'] as String,
              color: tile['color'] as Color,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => tile['screen'] as Widget)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTile({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
