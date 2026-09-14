import 'package:flutter/material.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/l10n/strings.dart';

class ChatProfileScreen extends StatelessWidget {
  final String userName;

  const ChatProfileScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: CustomScrollView(
        slivers: [
          // 🖼️ Large Institutional Profile Header
          SliverAppBar(
            expandedHeight: 320.0,
            pinned: true,
            backgroundColor: StarlightTheme.primaryBlue,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(userName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: StarlightTheme.primaryBlue.withOpacity(0.8),
                    child: Center(
                      child: Text(
                          userName.isNotEmpty ? userName[0] : "S",
                          style: const TextStyle(fontSize: 100, color: Colors.white24, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🏛️ Profile Content
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 10),

              // Bio / Role Section
              _buildInfoTile(tr('roleLabel'), tr('sampleFacultyTitle'), Icons.work_outline),
              _buildInfoTile(tr('institutionId'), "ST-2024-0042", Icons.badge_outlined),

              const SizedBox(height: 10),
              _buildMediaSection(),

              const SizedBox(height: 10),
              _buildSettingsTile(Icons.notifications_none, tr('muteNotifications'), Colors.black87),
              _buildSettingsTile(Icons.history_edu, tr('academicRecords'), Colors.black87),
              _buildSettingsTile(Icons.security, tr('encryptionStatus'), Colors.black87),

              const SizedBox(height: 10),
              _buildSettingsTile(Icons.block, tr('blockFaculty'), Colors.red),
              _buildSettingsTile(Icons.report_problem_outlined, tr('reportToAdmin'), Colors.red, isLast: true),

              const SizedBox(height: 50), // Bottom padding
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Icon(icon, color: StarlightTheme.primaryBlue, size: 22),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('sharedResourcesDocs'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, i) => Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12.0),
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: StarlightTheme.primaryBlue.withOpacity(0.1)),
                ),
                child: const Icon(Icons.description_outlined, color: StarlightTheme.primaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, Color color, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : Colors.grey.withOpacity(0.1))),
      ),
      child: ListTile(
        tileColor: Colors.white,
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w400)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}