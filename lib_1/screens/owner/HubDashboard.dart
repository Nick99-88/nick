import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/app_routes.dart';
import '../../chat_system/whatsapp_chat.dart';
import '../../timetable_directory/screens/timetable_directory.dart';
import '../../video_directory/screens/video_directory.dart';
import '../../library_directory/screens/library_directory_screen.dart';
import '../../library_directory/screens/library_saved_screen.dart';
import '../../side/screens/side_ide_screen.dart';
import '../../side/screens/challenges_screen.dart';
import '../hub/wallet_screen.dart';
import '../hub/tts_converter_screen.dart';
import '../hub/booksmith_screen.dart';
import '../../chatting_rooms/screens/rtc_lobby_screen.dart';
import '../../excel/main_screen.dart';
import '../../widgets/starlight_mailbox.dart';
import '../../chatting_platform/phone_number_verification_screen.dart';
import '../social/social_main_screen.dart';

class HubDashboard extends StatefulWidget {
  const HubDashboard({super.key});

  @override
  State<HubDashboard> createState() => _HubDashboardState();
}

class _HubDashboardState extends State<HubDashboard> {
  bool _isOnline = false;
  int _unsyncedCount = 0;

  @override
  void initState() {
    super.initState();
    _updateStatus();
  }

  Future<void> _updateStatus() async {
    setState(() {
      _isOnline = true; // Default to online for now
      _unsyncedCount = 0; // Default to 0 for now
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 🏛️ Header with offline status
          SliverAppBar(
            expandedHeight: 120,
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            actions: [],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Starlight Hub",
                    style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    _isOnline ? 'Connected to server' : 'Working offline',
                    style: TextStyle(
                      color: _isOnline ? Colors.green : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          // 🏛️ Hub Features Grid
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.1,
              children: [
                _buildHubCard(
                  context,
                  title: "Messaging",
                  subtitle: "Phone Verified Chat",
                  icon: Icons.verified_user,
                  color: Colors.deepOrange,
                  onTap: () async {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PhoneNumberVerificationScreen()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Library",
                  subtitle: "E-Books & Docs",
                  icon: Icons.menu_book_rounded,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryDirectoryScreen()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Saved Notes",
                  subtitle: "Bookmarks",
                  icon: Icons.bookmark_rounded,
                  color: Colors.amber.shade700,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LibrarySavedScreen()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Wallet",
                  subtitle: "Fee & Payroll",
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Mailbox",
                  subtitle: "Formal Notices",
                  icon: Icons.mark_as_unread_outlined,
                  color: Colors.purple,
                  onTap: () {
                    StarlightMailbox.show(context);
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Challenges",
                  subtitle: "Math & Logic",
                  icon: Icons.psychology_outlined,
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SideChallengesScreen()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "SIDE IDE",
                  subtitle: "Code & Debug",
                  icon: Icons.code_rounded,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SideIdeScreen()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Institution",
                  subtitle: "Global View",
                  icon: Icons.public_rounded,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SocialMainScreen(initialIndex: 0)));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Excel",
                  subtitle: "Export Reports",
                  icon: Icons.table_chart_outlined,
                  color: Colors.green.shade700,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SpreadsheetEditorScreen()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "RTC Rooms",
                  subtitle: "Video & Audio Calls",
                  icon: Icons.video_call_rounded,
                  color: Colors.deepPurpleAccent,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.rtcLobby);
                  },
                ),
                _buildHubCard(
                  context,
                  title: "TimeTable",
                  subtitle: "Schedule & Alarms",
                  icon: Icons.schedule_rounded,
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetableDirectory()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Videos",
                  subtitle: "Watch & Upload",
                  icon: Icons.play_circle_outline_rounded,
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const VideoDirectory()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "Text to Speech",
                  subtitle: "Convert & Download",
                  icon: Icons.record_voice_over,
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TtsConverterScreen()));
                  },
                ),
                _buildHubCard(
                  context,
                  title: "BookSmith",
                  subtitle: "Write & Read Docs",
                  icon: Icons.auto_stories,
                  color: Colors.brown,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const BookSmithScreen()));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF607D8B))),
            ],
          ),
        ),
      ),
    );
  }
}