import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/institution/dashboard_service.dart';

class StarlightFCM {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _messaging.getToken();
      if (token != null) {
        await updateTokenOnServer(token);
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle foreground alerts for the mailbox
    });
  }

  static Future<void> updateTokenOnServer(String token) async {
    try {
      final service = DashboardService();
     // await service.updateFCMToken(token);
      print("FCM Token Synced with Institution Backend");
    } catch (e) {
      print("Token Sync Error: $e");
    }
  }
}