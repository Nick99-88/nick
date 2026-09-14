import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import '../core/router_gateway.dart';
import '../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // This function can contain your Firebase init, permission requests, etc.
    // For now, we'll just simulate a delay and then call the router.

    // Request permissions (example)
    await _requestPermissions();

    // Add a delay for branding
    await Future.delayed(const Duration(seconds: 2));

    // Hand over to the router
    if (mounted) {
      debugPrint("🏛️ Engine: Handing over to Universal Router...");
      await UniversalRouter.routeUser(context);
    }
  }

  Future<void> _requestPermissions() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint("🏛️ Engine: Permission Denied. Exiting...");
      if (Platform.isAndroid) await SystemNavigator.pop();
      else exit(0);
    } else {
      debugPrint('🏛️ Permission: System UI Authorized');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: StarlightTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "Starlight Super Console",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
