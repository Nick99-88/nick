import 'package:flutter/material.dart';
import '../../core/storage.dart';
import '../../widgets/profile_avatar.dart';
import '../../services/platform_api_service.dart';
import 'website_creator_screen.dart';
import 'container_terminal_screen.dart';
import '../../event_ingestion/screens/ingestion_dashboard_screen.dart';
import '../../services_management/screens/services_management_screen.dart';

class DeveloperDashboardScreen extends StatefulWidget {
  final Function(String url)? onLaunchUrl;
  final Function(String html)? onLaunchHtml;

  const DeveloperDashboardScreen({
    super.key,
    this.onLaunchUrl,
    this.onLaunchHtml,
  });

  @override
  State<DeveloperDashboardScreen> createState() => _DeveloperDashboardScreenState();
}

class _DeveloperDashboardScreenState extends State<DeveloperDashboardScreen> {
  final PlatformApiService _api = PlatformApiService();

  bool _isLoading = true;
  String? _error;
  bool _needsSetup = false;

  PlatformUserProfile? _profile;
  PlatformSubscription? _subscription;
  List<PlatformProject> _projects = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _needsSetup = false;
    });

    try {
      final results = await Future.wait([
        _api.getUserProfile(),
        _api.getSubscriptionStatus(),
        _api.getHostedProjects(),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = results[0] as PlatformUserProfile;
        _subscription = results[1] as PlatformSubscription;
        _projects = results[2] as List<PlatformProject>;
        _isLoading = false;
      });
    } on PlatformApiException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 404) {
        setState(() {
          _needsSetup = true;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _capitalizedRole {
    final role = _profile?.role ?? 'student';
    if (role.isEmpty) return 'Explorer';
    return role[0].toUpperCase() + role.substring(1);
  }

  Color _roleBadgeColor() {
    switch (_profile?.role) {
      case 'teacher':
        return const Color(0xFF58A6FF);
      case 'student':
        return const Color(0xFF2EA043);
      case 'staff':
        return const Color(0xFFBC8CFF);
      case 'owner':
        return const Color(0xFFF0883E);
      default:
        return const Color(0xFF8B949E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_needsSetup) {
      return _buildSetupState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIdentityHeader(),
          const SizedBox(height: 20),
          _buildSubscriptionCard(),
          const SizedBox(height: 24),
          _buildToolTiles(),
          const SizedBox(height: 24),
          _buildProjectsSection(),
        ],
      ),
    );
  }

  Widget _buildSetupState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF58A6FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.dashboard_customize_rounded,
                color: Color(0xFF58A6FF),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Developer Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Set up your personal dashboard to track your projects, subscription, and activity across the platform.',
              style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 260,
              child: ElevatedButton.icon(
                onPressed: _createDashboard,
                icon: const Icon(Icons.rocket_launch_rounded, size: 20),
                label: const Text(
                  'Create Dashboard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDashboard() async {
    setState(() {
      _isLoading = true;
      _needsSetup = false;
    });

    try {
      await _api.createDashboard();
      await _fetchAll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
              backgroundColor: const Color(0xFF21262D),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading your dashboard...',
            style: TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDA3633).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFDA3633),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connection Offline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: OutlinedButton.icon(
                onPressed: _fetchAll,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF58A6FF),
                  side: BorderSide(color: const Color(0xFF58A6FF).withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildOfflineFallbackContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineFallbackContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                userId: _profile?.id ?? '',
                name: _profile?.name ?? 'Explorer',
                radius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profile?.name ?? 'Explorer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _capitalizedRole,
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF21262D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Using cached identity. Connect to the server to load full dashboard data.',
              style: TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            userId: _profile?.id ?? '',
            name: _profile?.name ?? 'Explorer',
            radius: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile?.name ?? 'Explorer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _roleBadgeColor().withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _roleBadgeColor().withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    _capitalizedRole,
                    style: TextStyle(
                      color: _roleBadgeColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final sub = _subscription;
    final isActive = sub?.isActive ?? false;
    final days = sub?.remainingDays ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF161B22),
            isActive ? const Color(0xFF0D3A1E) : const Color(0xFF3A0D0D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF2EA043).withOpacity(0.3)
              : const Color(0xFFDA3633).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${sub?.tier ?? 'Free'} Subscription',
                style: const TextStyle(
                  color: Color(0xFFC9D1D9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF2EA043).withOpacity(0.15)
                      : const Color(0xFFDA3633).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF2EA043).withOpacity(0.4)
                        : const Color(0xFFDA3633).withOpacity(0.4),
                  ),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'EXPIRED',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF2EA043) : const Color(0xFFDA3633),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$days',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'days remaining',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sub?.expiresAt != null ? 'Renews on ${sub!.expiresAt}' : '',
            style: const TextStyle(
              color: Color(0xFF484F58),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF21262D),
                foregroundColor: const Color(0xFF58A6FF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFF30363D)),
                ),
              ),
              child: const Text(
                'Renew / Upgrade Account',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolTiles() {
    return Row(
      children: [
        Expanded(child: _buildIngestionTile()),
        const SizedBox(width: 12),
        Expanded(child: _buildServicesManagementTile()),
      ],
    );
  }

  Widget _buildIngestionTile() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IngestionDashboardScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF58A6FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.sensors_rounded,
                    color: Color(0xFF58A6FF),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Event Ingestion Console',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Streams, webhooks & alerts',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesManagementTile() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ServicesManagementScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6A1B9A).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    color: Color(0xFFBC8CFF),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Services Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'GitHub, Railway & cloud keys',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hosted Projects',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_projects.length} active',
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const WebsiteCreatorScreen()),
              );
              if (created == true) _fetchAll();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Website'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2EA043),
              side: BorderSide(color: const Color(0xFF2EA043).withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_projects.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const Column(
              children: [
                Icon(Icons.folder_open_rounded, color: Color(0xFF484F58), size: 40),
                SizedBox(height: 12),
                Text(
                  'No projects deployed yet',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                ),
              ],
            ),
          )
        else
          ..._projects.map(_buildProjectCard),
      ],
    );
  }

  Widget _buildProjectCard(PlatformProject project) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: project.sideProjectId != null
                      ? const Color(0xFFBC8CFF).withOpacity(0.12)
                      : const Color(0xFF58A6FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  project.sideProjectId != null ? Icons.dns_rounded : Icons.code_rounded,
                  color: project.sideProjectId != null ? const Color(0xFFBC8CFF) : const Color(0xFF58A6FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.language,
                          color: Color(0xFF8B949E),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          project.networkAddress,
                          style: const TextStyle(
                            color: Color(0xFF58A6FF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (project.htmlContent != null && widget.onLaunchHtml != null) {
                      widget.onLaunchHtml!(project.htmlContent!);
                    } else if (widget.onLaunchUrl != null) {
                      widget.onLaunchUrl!(project.targetUrl);
                    }
                  },
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Launch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF58A6FF),
                    side: BorderSide(color: const Color(0xFF58A6FF).withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (project.sideProjectId != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final name = project.networkAddress
                          .replaceAll('starlight.project.', '')
                          .replaceAll('.html', '');
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ContainerTerminalScreen(
                          websiteName: name,
                          projectName: project.title,
                        )),
                      );
                    },
                    icon: const Icon(Icons.terminal_rounded, size: 16),
                    label: const Text('Build'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFBC8CFF),
                      side: BorderSide(color: const Color(0xFFBC8CFF).withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
