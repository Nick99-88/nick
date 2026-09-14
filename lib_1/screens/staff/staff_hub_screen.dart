import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../screens/hub/wallet_screen.dart';
import '../../video_directory/screens/video_directory.dart';
import '../../timetable_directory/screens/timetable_directory.dart';
import '../../qr_portal/qr_portal_screen.dart';
import '../../chat_system/chat_system_entry.dart' as chat_system;

class StaffHubScreen extends StatelessWidget {
  const StaffHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Hub", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildHubTile(context, Icons.wallet, "Wallet", const WalletScreen()),
          _buildHubTile(context, Icons.video_library, "Videos", const VideoDirectory()),
          _buildHubTile(context, Icons.schedule, "Timetable", const TimetableDirectory()),
          _buildHubTile(context, Icons.qr_code, "QR Portal", const QRPortalScreen()),
          _buildHubTile(context, Icons.chat, "Chatting", const chat_system.WhatsAppChatEntry()),
        ],
      ),
    );
  }


  Widget _buildHubTile(BuildContext context, IconData icon, String title, Widget screen) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, size: 48, color: Colors.teal.shade700), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))],
        ),
      ),
    );
  }
}
