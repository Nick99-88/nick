import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../core/theme.dart';
import '../../core/ads_setup.dart';
import '../../core/ad_service.dart';
import '../../shop/shop_screen.dart';
import 'dashboard.dart';
import 'doc.dart';
import '../owner/HubDashboard.dart';
import '../../qr_portal/qr_portal_screen.dart';
import 'financials_screen.dart';
import 'profile.dart';

class MainStudentScreen extends StatefulWidget {
  const MainStudentScreen({super.key});

  @override
  State<MainStudentScreen> createState() => _MainStudentScreenState();
}

class _MainStudentScreenState extends State<MainStudentScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedIndex >= _screens.length) {
        setState(() => _selectedIndex = 0);
      }
      // Ensure ads are preloaded when student screen opens
      _preloadAds();
    });
  }

  void _preloadAds() {
    if (!AdConfig.isInitialized) {
      debugPrint('📱 [Student] Ads not initialized yet, skipping preload.');
      return;
    }
    debugPrint('📱 [Student] Preloading ads on screen init...');
    if (!AdService.instance.isRewardedAdReady) {
      AdService.instance.loadRewardedAd();
    }
  }

  Future<void> _watchAd() async {
    debugPrint('📱 [Student] Watch Ad icon tapped.');

    if (!AdConfig.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ad engine is still loading. Please wait a moment.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('Loading reward ad...'),
            ],
          ),
          backgroundColor: Colors.blue.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Load ad if not ready
    if (!AdService.instance.isRewardedAdReady) {
      await AdService.instance.loadRewardedAd();
    }

    // Show the rewarded ad
    final reward = await AdService.instance.showRewardedAd(
      onRewarded: () async {
        // Credit the user with rewards
        final credits = await AdService.instance.creditRewardedAdUser();
        debugPrint('📱 [Student] Rewarded! Credits: $credits');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.stars, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Earned ${credits['silver']} Silver + ${credits['ai_credits']} AI Credits!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );

    if (!reward && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ad was not completed. Try again!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  final List<Widget> _screens = [
    const StudentDashboard(),
    const QRPortalScreen(),
    const StudentDoc(),
    const HubDashboard(),
    const StudentFinancialsScreen(),
    const StudentProfile(),
  ];

  final List<String> _titles = [
    "STUDENT DASHBOARD",
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
                      icon: Icon(
                        Icons.play_circle_outline,
                        size: 22,
                        color: ready ? Colors.green.shade600 : Colors.grey,
                      ),
                      onPressed: _watchAd,
                      tooltip: ready ? "Watch Ad — Earn Rewards" : "Loading Ad...",
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined, size: 22),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
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
            activeColor: Colors.green.shade700,
            iconSize: 20,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tabBackgroundColor: Colors.green.shade700.withOpacity(0.08),
            color: Colors.black45,
            duration: const Duration(milliseconds: 300),
            textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700),
            tabs: const [
              GButton(icon: Icons.dashboard, text: 'Dashboard'),
              GButton(icon: Icons.qr_code, text: 'QR Portal'),
              GButton(icon: Icons.description, text: 'Docs'),
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
