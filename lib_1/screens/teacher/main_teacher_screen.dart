import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../core/theme.dart';
import '../../core/ads_setup.dart';
import '../../core/ad_service.dart';
import '../owner/document_vault_screen.dart';
import '../owner/HubDashboard.dart';
import '../../qr_portal/qr_portal_screen.dart';
import 'financials_screen.dart';
import '../../shop/shop_screen.dart';
import 'dashboard.dart';
import 'profile.dart';

class MainTeacherScreen extends StatefulWidget {
  const MainTeacherScreen({super.key});

  @override
  State<MainTeacherScreen> createState() => _MainTeacherScreenState();
}

class _MainTeacherScreenState extends State<MainTeacherScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedIndex >= _screens.length) {
        setState(() => _selectedIndex = 0);
      }
      _preloadAds();
    });
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

  final List<Widget> _screens = [
    const TeacherConsole(),
    const QRPortalScreen(),
    const DocumentVaultScreen(),
    const HubDashboard(),
    const TeacherFinancialsScreen(),
    const TeacherProfile(),
  ];

  final List<String> _titles = [
    "TEACHER DASHBOARD",
    "QR PORTAL",
    "DOCUMENTS",
    "HUB",
    "FINANCIALS",
    "PROFILE",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: _selectedIndex == 2 || _selectedIndex == 3 || _selectedIndex == 4
          ? AppBar(
              toolbarHeight: 0,
              backgroundColor: Colors.white,
              elevation: 0,
            )
          : AppBar(
              title: Text(_titles[_selectedIndex],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
              centerTitle: true,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF263238),
              elevation: 0.5,
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
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ShopScreen()));
                  },
                  tooltip: "Shop",
                ),
              ],
            ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: GNav(
            selectedIndex: _selectedIndex,
            onTabChange: (index) => setState(() => _selectedIndex = index),
            gap: 4,
            activeColor: StarlightTheme.primaryBlue,
            iconSize: 20,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tabBackgroundColor: StarlightTheme.primaryBlue.withOpacity(0.08),
            color: Colors.black45,
            duration: const Duration(milliseconds: 300),
            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
            tabs: const [
              GButton(icon: Icons.dashboard, text: 'Dashboard'),
              GButton(icon: Icons.qr_code, text: 'QR Portal'),
              GButton(icon: Icons.folder_open, text: 'Documents'),
              GButton(icon: Icons.hub, text: 'Hub'),
              GButton(icon: Icons.account_balance_wallet_rounded, text: 'Financials'),
              GButton(icon: Icons.person, text: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
