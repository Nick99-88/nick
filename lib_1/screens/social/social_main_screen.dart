import 'package:flutter/material.dart';
import '../../widgets/starlight_nav_bar.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/app_routes.dart';
import '../../core/ads_setup.dart';
import '../../core/ad_service.dart';
import '../../services/socket/socket_service.dart';
import '../../services/social/friend_request_service.dart';
import '../../shop/shop_screen.dart';
import 'explore_screen.dart';
import 'student_explore_screen.dart';
import 'ai_assistant_screen.dart';
import 'vault_browser_screen.dart';
import 'developer_dashboard_screen.dart';
import 'inbox_screen.dart';
import 'widgets/request_box.dart';
import '../../chat_system/widgets/call_overlay_host.dart';
import '../../chat_system/services/chat_local_notification_service.dart';

class SocialMainScreen extends StatefulWidget {
  final int initialIndex;
  const SocialMainScreen({super.key, this.initialIndex = 0});

  @override
  State<SocialMainScreen> createState() => _SocialMainScreenState();
}

class _SocialMainScreenState extends State<SocialMainScreen> {
  late int _selectedIndex;
  bool _hasInstitution = false;
  String _role = '';
  bool _isSocketConnected = false;
  final GlobalKey<VaultBrowserScreenState> _vaultBrowserKey = GlobalKey();

  // Friend Request State
  final FriendRequestService _friendRequestService = FriendRequestService();
  final List<FriendRequest> _friendRequests = [];
  bool _showRequestBox = false;

  bool _isIndividualStudent() {
    if (_hasInstitution) return false;
    // Only users whose role is "student" and have no institution are
    // treated as individual students. Owners/teachers/staff always get
    // the full explore page.
    return _role.toLowerCase() == 'student';
  }

  Widget _pageForIndex(int index) {
    switch (index) {
      case 0:
        return _isIndividualStudent() ? const ExplorePage(initialRole: 'student') : const ExplorePage();
      case 1:
        return const InboxScreen();
      case 2:
        return const AiAssistantScreen();
      case 3:
        return VaultBrowserScreen(key: _vaultBrowserKey);
      case 4:
        return DeveloperDashboardScreen(
          onLaunchUrl: (url) {
            _vaultBrowserKey.currentState?.navigateToUrl(url);
            setState(() => _selectedIndex = 3);
          },
          onLaunchHtml: (html) {
            _vaultBrowserKey.currentState?.loadServerString(html);
            setState(() => _selectedIndex = 3);
          },
        );
      default:
        return const ExplorePage();
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _initializeSocket();
    _checkInstitutionStatus();
    _loadRole();
    _fetchPendingRequests();
    ChatLocalNotificationService.instance.setContext(context);
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

  @override
  void dispose() {
    SocketService.disconnect();
    super.dispose();
  }

  void _initializeSocket() async {
    SocketService.setCallbacks(
      onUserConnected: (userData) async {
        final user = userData['user'] as Map<String, dynamic>?;
        setState(() {
          _hasInstitution = user?['has_institution'] ?? false;
          _isSocketConnected = true;
        });
        final phone = user?['phone'] as String?;
        if (phone != null && phone.isNotEmpty) {
          await StarlightStorage.setUserPhoneNumber(phone);
        }
      },
    );
    await SocketService.connect(source: 'SocialMainScreen');
  }

  Future<void> _checkInstitutionStatus() async {
    final hasInstitution = await StarlightStorage.hasInstitution();
    setState(() => _hasInstitution = hasInstitution);
  }

  Future<void> _loadRole() async {
    final role = await StarlightStorage.getUserRole();
    if (mounted) setState(() => _role = role ?? '');
  }

  Future<void> _fetchPendingRequests() async {
    try {
      final requests = await _friendRequestService.getPendingRequests();
      if (!mounted) return;
      setState(() {
        _friendRequests.clear();
        for (final req in requests) {
          _friendRequests.add(FriendRequest(
            id: req['id'] ?? '',
            name: req['sender_name'] ?? 'Unknown',
            role: req['sender_role'] ?? 'User',
            timestamp: DateTime.tryParse(req['created_at'] ?? '') ?? DateTime.now(),
          ));
        }
      });
    } catch (e) {
      // Silent fail - will retry on next open
    }
  }

  void _handleRequestResponse(String requestId, bool accepted) async {
    try {
      await _friendRequestService.respondToRequest(requestId, accepted);
      if (!mounted) return;
      final req = _friendRequests.firstWhere((r) => r.id == requestId);
      setState(() {
        req.status = accepted ? 'accepted' : 'rejected';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accepted ? "You accepted ${req.name}" : "You rejected ${req.name}"),
          backgroundColor: accepted ? Colors.green : Colors.red,
        ),
      );
      // Remove from list after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _friendRequests.removeWhere((r) => r.id == requestId));
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleRequestBox() {
    setState(() => _showRequestBox = !_showRequestBox);
    if (_showRequestBox) {
      _fetchPendingRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallOverlayHost(
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.maybePop(context),
          tooltip: "Back",
        ),
        title: const Text(
          "STARLIGHT GLOBAL",
          style: TextStyle(
            color: StarlightTheme.primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.green, size: 22),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
            },
            tooltip: "Shop",
          ),
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
            icon: const Icon(Icons.logout, color: Colors.red, size: 22),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
       body: Stack(
        children: [
          _pageForIndex(_selectedIndex),
          // Request Box Overlay
          if (_showRequestBox)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showRequestBox = false),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
          if (_showRequestBox)
            Positioned(
              right: 0,
              bottom: 0,
              child: RequestBox(
                requests: _friendRequests,
                onRespond: _handleRequestResponse,
                onClose: _toggleRequestBox,
              ),
            ),
        ],
      ),
      floatingActionButton: _buildRequestFab(),
      bottomNavigationBar: StarlightNavBar(
        selectedIndex: _selectedIndex,
        onTabChange: (index) {
          setState(() => _selectedIndex = index);
        },
        role: NavBarRole.social,
      ),
    ),
    );
  }

  Widget? _buildRequestFab() {
    if (_showRequestBox) return null;
    if (_selectedIndex == 2 || _selectedIndex == 3) return null;
    final pendingCount = _friendRequests.where((r) => r.status == 'pending').length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          onPressed: _toggleRequestBox,
          backgroundColor: Colors.white,
          tooltip: "Friend Requests",
          child: const Icon(Icons.person_add_alt_1_rounded, color: StarlightTheme.primaryBlue),
        ),
        if (pendingCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await StarlightStorage.clearAll();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}
