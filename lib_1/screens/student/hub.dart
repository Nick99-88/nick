import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../chat_system/chat_system_entry.dart';
import '../../side/screens/side_ide_screen.dart';
import '../../side/server/screens/server_ide_screen.dart';
import '../hub/wallet_screen.dart';

class StudentHub extends StatefulWidget {
  const StudentHub({super.key});

  @override
  State<StudentHub> createState() => _StudentHubState();
}

class _StudentHubState extends State<StudentHub> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Student Hub", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text("Connect, explore & manage", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 20),
          _buildMainTiles(),
        ],
      ),
    );
  }

  Widget _buildMainTiles() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _bigTile(icon: Icons.chat, title: "Chat System", subtitle: "Messages & groups", color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WhatsAppChatEntry())))),
            const SizedBox(width: 12),
            Expanded(child: _bigTile(icon: Icons.account_balance_wallet, title: "Wallet", subtitle: "Balance & payments", color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen())))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _bigTile(icon: Icons.local_library, title: "Library", subtitle: "Books & resources", color: Colors.orange, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Library coming soon!"))), comingSoon: true)),
            const SizedBox(width: 12),
            Expanded(child: _bigTile(icon: Icons.storefront, title: "Shop", subtitle: "Institution store", color: Colors.purple, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shop coming soon!"))), comingSoon: true)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _bigTile(icon: Icons.campaign, title: "Notices", subtitle: "Announcements", color: Colors.red, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notices coming soon!"))))),
            const SizedBox(width: 12),
            Expanded(child: _bigTile(icon: Icons.event, title: "Events", subtitle: "Calendar & schedules", color: Colors.indigo, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Events coming soon!"))))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _bigTile(icon: Icons.code, title: "SIDE IDE", subtitle: "Code, run & debug", color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SideIdeScreen())))),
            const SizedBox(width: 12),
            Expanded(child: _bigTile(icon: Icons.cloud, title: "Server IDE", subtitle: "Deploy & host", color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServerIdeScreen())))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _bigTile(icon: Icons.emoji_events, title: "Challenges", subtitle: "Earn Dev-Points", color: Colors.amber, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SideIdeScreen())))),
            const SizedBox(width: 12),
            Expanded(child: _bigTile(icon: Icons.storefront, title: "Shop", subtitle: "Institution store", color: Colors.purple, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shop coming soon!"))), comingSoon: true)),
          ],
        ),
      ],
    );
  }

  Widget _bigTile({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap, bool comingSoon = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
                if (comingSoon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Text("SOON", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
