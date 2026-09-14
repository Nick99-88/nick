import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../core/router_gateway.dart';
import '../../core/socket_vault.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';

class StudentsFeaturesWidget extends StatefulWidget {
  const StudentsFeaturesWidget({super.key});

  @override
  State<StudentsFeaturesWidget> createState() => _StudentsFeaturesWidgetState();
}

class _StudentsFeaturesWidgetState extends State<StudentsFeaturesWidget> {
  final List<_FeatureTile> _features = [
    _FeatureTile(
      title: 'Quiz',
      subtitle: 'Take quizzes and practice tests',
      icon: Icons.quiz_rounded,
      color: Colors.deepPurple,
      route: AppRoutes.studentQuiz,
    ),
    _FeatureTile(
      title: 'Side IDE',
      subtitle: 'Code editor with multi-language support',
      icon: Icons.code_rounded,
      color: Colors.indigo,
      route: AppRoutes.sideIde,
    ),
    _FeatureTile(
      title: 'BookSmith',
      subtitle: 'Document writer, scanner & reader',
      icon: Icons.auto_stories_rounded,
      color: Colors.teal,
      route: AppRoutes.booksmith,
    ),
    _FeatureTile(
      title: 'Text to Speech',
      subtitle: 'Convert text to natural voice audio',
      icon: Icons.record_voice_over_rounded,
      color: Colors.orange,
      route: AppRoutes.ttsConverter,
    ),
    _FeatureTile(
      title: 'Timetable',
      subtitle: 'Manage class schedules & alarms',
      icon: Icons.schedule_rounded,
      color: Colors.blue,
      route: AppRoutes.timetableDirectory,
    ),
    _FeatureTile(
      title: 'AI Dictionary',
      subtitle: 'Translate, define & explain words',
      icon: Icons.translate_rounded,
      color: Colors.green,
      route: AppRoutes.dictionary,
    ),
    _FeatureTile(
      title: 'Inbox',
      subtitle: 'Messages and friend requests',
      icon: Icons.mail_outline_rounded,
      color: Colors.pink,
      route: AppRoutes.studentInbox,
    ),
    _FeatureTile(
      title: 'Chat Rooms',
      subtitle: 'Video & audio group calls',
      icon: Icons.forum_rounded,
      color: Colors.indigo,
      route: AppRoutes.rtcLobby,
      arguments: {'showInstitutional': false},
    ),
    _FeatureTile(
      title: 'Hosting Dashboard',
      subtitle: 'Hosted projects & subscriptions',
      icon: Icons.dashboard_rounded,
      color: Colors.indigo,
      route: AppRoutes.socialPlatform,
      arguments: {'initialIndex': 4},
    ),
    _FeatureTile(
      title: 'Challenges',
      subtitle: 'Compete and earn Dev-Points',
      icon: Icons.emoji_events_rounded,
      color: Colors.amber,
      route: AppRoutes.studentChallenges,
    ),
    _FeatureTile(
      title: 'Document Translator',
      subtitle: 'Translate documents to multiple languages',
      icon: Icons.g_translate_rounded,
      color: Colors.pinkAccent,
      route: AppRoutes.documentTranslator,
    ),
    _FeatureTile(
      title: 'Explore',
      subtitle: 'Discover students nearby',
      icon: Icons.people_rounded,
      color: Colors.tealAccent,
      route: AppRoutes.explore,
      arguments: {'initialRole': 'student'},
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Students Features',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: const Color(0xFF263238),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    StarlightTheme.primaryBlue,
                    StarlightTheme.primaryBlue.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: StarlightTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.group_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Student Tools Hub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Access all your academic tools in one place',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_features.length} tools available',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Features Section Header
            const Text(
              'ACADEMIC TOOLS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.black26,
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 12),

            // Features Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _features.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                return _buildFeatureCard(_features[index]);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    StarlightSocket().close();
    await StarlightStorage.logout();
    if (mounted) {
      UniversalRouter.routeUser(context);
    }
  }

  Widget _buildFeatureCard(_FeatureTile feature) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, feature.route, arguments: feature.arguments),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: feature.color.withOpacity(0.15), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: feature.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      feature.icon,
                      color: feature.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF263238),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: feature.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Open',
                      style: TextStyle(
                        color: feature.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: feature.color.withOpacity(0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final Object? arguments;

  const _FeatureTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.arguments,
  });
}