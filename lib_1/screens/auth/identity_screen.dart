import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/sign.dart';
import '../../services/auth/app_identity_service.dart';
import '../../widgets/intro_widgets/onboarding_overlay.dart';
import '../../core/storage.dart';
import 'login_screen.dart';
import '../../core/app_routes.dart';
import '../../l10n/strings.dart';

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  bool _isLoading = false;
  bool _showOnboarding = false;
  String? _selectedAppId;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await StarlightStorage.isOnboardingCompleted();
    if (mounted) {
      setState(() => _showOnboarding = !completed);
    }
  }

  static const List<Map<String, dynamic>> _systems = [
    {
      'id': 'starlight_video',
      'name': 'Video System',
      'nameKey': 'sysVideoName',
      'descKey': 'sysVideoDesc',
      'icon': Icons.play_circle_fill_rounded,
      'color': Color(0xFFE53935),
      'desc': 'Stream, upload and manage video content',
    },
    {
      'id': 'starlight_library',
      'name': 'Library System',
      'nameKey': 'sysLibraryName',
      'descKey': 'sysLibraryDesc',
      'icon': Icons.library_books_rounded,
      'color': Color(0xFF1E88E5),
      'desc': 'Access digital library and reading resources',
    },
    {
      'id': 'starlight_chat',
      'name': 'Chatting System',
      'nameKey': 'sysChatName',
      'descKey': 'sysChatDesc',
      'icon': Icons.chat_rounded,
      'color': Color(0xFF43A047),
      'desc': 'Real-time messaging and conversations',
    },
    {
      'id': 'starlight_qr',
      'name': 'QR Portals',
      'nameKey': 'sysQrName',
      'descKey': 'sysQrDesc',
      'icon': Icons.qr_code_scanner_rounded,
      'color': Color(0xFF8E24AA),
      'desc': 'Scan and generate QR code portals',
    },
    {
      'id': 'starlight_rooms',
      'name': 'Chatting Rooms',
      'nameKey': 'sysRoomsName',
      'descKey': 'sysRoomsDesc',
      'icon': Icons.forum_rounded,
      'color': Color(0xFF00897B),
      'desc': 'Join group rooms and live discussions',
    },
    {
      'id': 'starlight_lib_mgmt',
      'name': 'Library Management',
      'nameKey': 'sysLibMgmtName',
      'descKey': 'sysLibMgmtDesc',
      'icon': Icons.auto_stories_rounded,
      'color': Color(0xFFF4511E),
      'desc': 'Local library data management and catalog',
    },
    {
      'id': 'starlight_browser',
      'name': 'Browser',
      'nameKey': 'sysBrowserName',
      'descKey': 'sysBrowserDesc',
      'icon': Icons.language_rounded,
      'color': Color(0xFF3949AB),
      'desc': 'In-app web browser and research tools',
    },
    {
      'id': 'starlight_ide',
      'name': 'Coding IDE',
      'nameKey': 'sysIdeName',
      'descKey': 'sysIdeDesc',
      'icon': Icons.code_rounded,
      'color': Color(0xFF546E7A),
      'desc': 'Write, test and run code on the go',
    },
    {
      'id': 'starlight_student_portals',
      'name': 'Students Features',
      'nameKey': 'sysStudentsName',
      'descKey': 'sysStudentsDesc',
      'icon': Icons.group_rounded,
      'color': Color(0xFFEC407A),
      'desc': 'Student admission, profiles and academic records management',
    },
    {
      'id': 'starlight_institution',
      'name': 'Institutional Management',
      'nameKey': 'sysInstitutionName',
      'descKey': 'sysInstitutionDesc',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFFFFB300),
      'desc': 'Full institution dashboard and admin control',
      'isMain': true,
    },
  ];

  void _onSystemSelected(Map<String, dynamic> system) async {
    final appId = system['id'] as String;
    final name = system['name'] as String;
    final displayName = tr(system['nameKey'] as String);

    setState(() {
      _isLoading = true;
      _selectedAppId = appId;
    });

    try {
      final success = await AppIdentityService.selectAppIdentity(appId, name);

      if (success) {
        await StarlightStorage.setAppId(appId);
        await StarlightStorage.setActiveAppName(name);

        if (!mounted) return;
        setState(() => _isLoading = false);

        StarlightUtils.showSuccessBox(context, tr('appActivated', {'name': displayName}));

        // LoginScreen triggers UniversalRouter.routeUser after auth,
        // which routes to StudentsFeaturesWidget when appId is student_portals
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        throw Exception("Selection failed");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _selectedAppId = null;
      });
      StarlightUtils.showErrorBox(context, "${tr('selectionFailed')}: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainSystem = _systems.firstWhere((s) => s['isMain'] == true);
    final otherSystems = _systems.where((s) => s['isMain'] != true).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text(tr('selectAppIdentity'),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.5)),
        backgroundColor: const Color(0xFF263238),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Main content
          if (_isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1A237E)),
                  SizedBox(height: 16),
                  Text(
                    tr('activating'),
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildMainCard(mainSystem),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        tr('otherSystems'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.black26,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    ...otherSystems.map(_buildSystemCard),
                  ],
                ),
              ),
            ),
          // Onboarding overlay
          if (_showOnboarding) OnboardingOverlay(
            onDismiss: () => setState(() => _showOnboarding = false),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(Map<String, dynamic> system) {
    final color = system['color'] as Color;

    return GestureDetector(
      onTap: () => _onSystemSelected(system),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(system['icon'] as IconData, color: Colors.white, size: 40),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tr('mainBadge'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              tr(system['nameKey'] as String),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tr(system['descKey'] as String),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tr('tapToActivate'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemCard(Map<String, dynamic> system) {
    final color = system['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _onSystemSelected(system),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(system['icon'] as IconData, color: color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(system['nameKey'] as String),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr(system['descKey'] as String),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
