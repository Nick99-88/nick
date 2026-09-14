import 'package:flutter/material.dart';
import '../core/storage.dart';

// Video System
import '../video_directory/screens/video_directory.dart';

// Library System
import '../library_directory/screens/library_directory_screen.dart';

// Chatting Platform
import '../chatting_platform/local_chat_id_screen.dart';
import '../chatting_platform/phone_number_verification_screen.dart';

// QR Portals
import '../qr_portal/qr_portal_screen.dart';

// Chatting Rooms
import '../chatting_rooms/screens/rtc_lobby_screen.dart';

// Library Management (local)
import '../library_management/screens/mode_selection_screen.dart';

// Browser
import '../screens/social/vault_browser_screen.dart';

// Coding IDE
import '../side/screens/side_ide_screen.dart';

// students features
import '../widgets/students_features_widget.dart';

class TabsRouter {
  /// Routes the user to the correct screen based on the active app identity.
  /// Returns true if routing was handled, false if the app identity is
  /// institutional (caller should use the role-based router instead).
  static Future<bool> route(BuildContext context) async {
    final appId = await StarlightStorage.getAppId();

    if (appId == null || appId.isEmpty) return false;

    // Institutional management uses the existing role-based router
    if (appId == 'starlight_institution') return false;

    if (!context.mounted) return false;

    final screen = await _resolveScreen(appId);
    if (screen == null) return false;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
    return true;
  }

  /// Returns the entry screen for a given app ID, or null if unknown.
  static Future<Widget?> _resolveScreen(String appId) async {
    switch (appId) {
      case 'starlight_video':
        return const VideoDirectory();
      case 'starlight_library':
        return const LibraryDirectoryScreen();
      case 'starlight_chat':
        final verifiedPhone = await StarlightStorage.getVerifiedPhone();
        final chatVerified = await StarlightStorage.getChatVerified();
        if (verifiedPhone != null && chatVerified == true) {
          return const LocalChatIdScreen();
        }
        return const PhoneNumberVerificationScreen();
      case 'starlight_qr':
        return const QRPortalScreen();
      case 'starlight_rooms':
        return const RtcLobbyScreen();
      case 'starlight_lib_mgmt':
        return const ModeSelectionScreen();
      case 'starlight_browser':
        return const VaultBrowserScreen();
      case 'starlight_ide':
        return const SideIdeScreen();
      case 'starlight_student_portals':
        return const StudentsFeaturesWidget();
      default:
        return null;
    }
  }
}
