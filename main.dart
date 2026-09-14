import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/app_routes.dart';
import 'core/router_gateway.dart';
import 'core/loading.dart';
import 'core/firebase_options.dart';
import 'core/permission_dialog.dart';
import 'core/storage.dart';
import 'core/theme_mode.dart';
import 'core/unseen_count_service.dart';
import 'screens/app_themes.dart';
import 'screens/theme_controller.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'services/setup/setup_service.dart';
import 'timetable_directory/services/local_alarm_scheduler.dart';
import 'video_directory/services/global_audio_notification_service.dart';
import 'chat_system/services/call_kit_service.dart';
import 'chat_system/services/chat_local_notification_service.dart';
import 'chat_system/services/call_signaling_service.dart';
import 'chat_system/screens/unified_call_screen.dart';
import 'chat_system/services/audio_playback_service.dart';
import 'chat_system/services/media_transfer_service.dart';
import 'services/fcm_service.dart';
import 'excel/native_bridge.dart';
import 'services/nearby_permissions.dart';
import 'package:home_widget/home_widget.dart';
import 'timetable_directory/services/task_service.dart';
import 'timetable_directory/services/widget_update_service.dart';
import 'screens/animated_splash_screen.dart';
import 'core/ads_setup.dart';
import 'core/ad_service.dart';
import 'services/subscription/subscription_service.dart';
import 'screens/owner/tabs/database/dashboard_sync_service.dart';
import 'screens/shared/biometric_lock_screen.dart';
import 'core/ai_model_manager.dart';
import 'l10n/strings.dart';
import 'side/services/offline_python_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Check for notification data when app is launched from killed state
Future<void> _checkNotificationDataOnLaunch() async {
  try {
    const channel = MethodChannel('com.starlight.console/notification');
    final data = await channel.invokeMethod('getNotificationData') as Map<dynamic, dynamic>?;
    
    if (data != null && data.isNotEmpty) {
      final notificationType = data['notification_type'] as String?;
      if (notificationType == 'incoming_call') {
        debugPrint('🏛️ App launched from incoming call notification');
        // Store the data for later processing when context is available
        _pendingCallData = {
          'call_id': data['call_id'] ?? '',
          'caller_name': data['caller_name'] ?? '',
          'caller_phone': data['caller_phone'] ?? '',
          'call_type': data['call_type'] ?? 'voice',
          'caller_avatar': data['caller_avatar'] ?? '',
        };
      }
    }
  } catch (e) {
    debugPrint('🏛️ Error checking notification data: $e');
  }
}

/// Store pending call data from notification launch
Map<String, String>? _pendingCallData;

/// Handle incoming call notification
void _handleCallNotification(Map<String, String> callData) {
  try {
    final callId = callData['call_id'] ?? '';
    final callerName = callData['caller_name'] ?? 'Unknown';
    final callerPhone = callData['caller_phone'] ?? '';
    final callType = callData['call_type'] ?? 'voice';
    final callerAvatar = callData['caller_avatar'] ?? '';
    
    debugPrint('🏛️ Handling call notification: $callerName ($callType)');
    
    // Show CallKit incoming call UI
    CallKitService.instance.showIncomingCall(
      callId: callId,
      callerName: callerName,
      callerHandle: callerPhone,
      callType: callType,
      extra: {'callerAvatar': callerAvatar},
    );
    
    // Also show a local notification as backup
    ChatLocalNotificationService.instance.showIncomingCall(
      callerName: callerName,
      callerPhone: callerPhone,
      callId: callId,
      callType: callType,
      callerAvatar: callerAvatar,
    );
  } catch (e) {
    debugPrint('🏛️ Error handling call notification: $e');
  }
}

/// 🏛️ Request P2P / Nearby Connection permissions
Future<void> requestP2PPermissions() async {
  await requestNearbyPermissions();
}

/// 🏛️ Request runtime permissions for voice/video calling and notifications
Future<void> requestAppPermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.notification, // POST_NOTIFICATIONS for Android 13+
    Permission.microphone,
    Permission.camera,
    Permission.scheduleExactAlarm, // SCHEDULE_EXACT_ALARM for Android 14+
    Permission.nearbyWifiDevices, // NEARBY_WIFI_DEVICES for Android 13+
  ].request();

  final context = navigatorKey.currentContext;
  if (context == null) return;

  if (statuses[Permission.microphone]!.isDenied) {
    debugPrint('🏛️ Microphone permission denied');
    await showPermissionDialog(
      context: context,
      title: 'Microphone Access Required',
      message: 'Microphone access is required for voice features. Please enable microphone access to use voice calling.',
      actionText: 'Open Settings',
      actionColor: Colors.red,
      onAction: () {
        openAppSettings();
      },
    );
    return;
  }

  if (statuses[Permission.camera]!.isDenied) {
    debugPrint('🏛️ Camera permission denied');
    await showPermissionDialog(
      context: context,
      title: 'Camera Access Required',
      message: 'Camera access is required for video features. Please enable camera access to use video calling.',
      actionText: 'Open Settings',
      actionColor: Colors.red,
      onAction: () {
        openAppSettings();
      },
    );
    return;
  }

  if (statuses[Permission.notification]!.isDenied) {
    debugPrint('🏛️ Notifications permission denied');
    await showPermissionDialog(
      context: context,
      title: 'Notification Access Required',
      message: 'Notification access is required to receive messages and alerts. Please enable notifications to stay connected.',
      actionText: 'Open Settings',
      actionColor: Colors.red,
      onAction: () {
        openAppSettings();
      },
    );
    return;
  }

  if (statuses[Permission.scheduleExactAlarm]!.isDenied) {
    debugPrint('🏛️ Schedule exact alarm permission denied');
    await showPermissionDialog(
      context: context,
      title: 'Exact Alarm Access Required',
      message: 'Exact alarm access is required for timely notifications and reminders. Please enable this permission for reliable notifications.',
      actionText: 'Open Settings',
      actionColor: Colors.red,
      onAction: () {
        openAppSettings();
      },
    );
    return;
  }

  if (statuses[Permission.nearbyWifiDevices]!.isDenied) {
    debugPrint('🏛️ Nearby WiFi devices permission denied');
    await showPermissionDialog(
      context: context,
      title: 'Nearby WiFi Devices Access Required',
      message: 'Nearby WiFi devices access is required for device discovery and connection features. Please enable this permission to scan for nearby devices.',
      actionText: 'Open Settings',
      actionColor: Colors.red,
      onAction: () {
        openAppSettings();
      },
    );
    return;
  }

  if (statuses[Permission.notification]!.isGranted) {
    debugPrint('🏛️ All permissions granted');
  }
}


@pragma('vm:entry-point')
void starlightWidgetCallback(Uri? uri) async {
  if (uri != null && uri.host == 'complete_task') {
    final taskId = uri.queryParameters['id'];
    if (taskId != null && taskId.isNotEmpty) {
      await TaskService.deleteTask(taskId);
    }
  }
  TaskService.updateWidgetWithNextTask();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Windows/Linux sqflite FFI initialization ──
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ── Badge service: load persisted unseen counts + sync app icon badge ──
  try {
    await unseenCounts.init();
  } catch (e) {
    debugPrint('🏛️ UnseenCount init error: $e');
  }

  // ── Phase 1: Pure Dart / no platform channels ──
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await HomeWidget.registerInteractivityCallback(starlightWidgetCallback);
    } catch (e) {
      debugPrint('🏛️ HomeWidget callback registration error: $e');
    }
  }

  try {
    NativeBridge.instance.initialize();
    debugPrint('🏛️ Native C++ engine initialized');
  } catch (e) {
    debugPrint('🏛️ Native engine unavailable: $e');
  }

  // Initialize timezone database
  tz_data.initializeTimeZones();

  // 🏛️ Load the selected language from storage before the UI builds
  try {
    await initL10n();
  } catch (e) {
    debugPrint('🏛️ initL10n error: $e');
  }

  // 🏛️ Load the stored theme mode from storage before the UI builds
  try {
    await initThemeMode();
  } catch (e) {
    debugPrint('🏛️ initThemeMode error: $e');
  }

  // ── Phase 1.5: AI Model Manager initialization ──
  try {
    await AIModelManager().checkAllModelsStatus();
    debugPrint('🏛️ AI Model Manager initialized');
  } catch (e) {
    debugPrint('🏛️ AI Model Manager init error: $e');
  }

  // ── Phase 2: Firebase initialization (MUST be before any Firebase plugin usage) ──
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('🏛️ Firebase initialized in main()');
  } catch (e) {
    debugPrint('🏛️ Firebase init error in main(): $e');
  }

  // ── Phase 3: Notification data check from killed-state launch (mobile only) ──
  if (Platform.isAndroid || Platform.isIOS) {
    await _checkNotificationDataOnLaunch();
  }

  // ── Phase 4: Widget update service (runs in background, safe to start early) ──
  WidgetUpdateService.start();

  // ── Phase 5: Ads (mobile only) ──
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      final adsReady = await AdConfig.initialize();
      if (adsReady) {
        AdService.instance.loadRewardedAd();
        AdService.instance.loadInterstitialAd();
        debugPrint('🏛️ Ads initialized and preloaded');
      }
    } catch (e) {
      debugPrint('🏛️ Ad engine init error: $e');
    }
  }

  // ── Phase 5b: Offline Python warm-up (mobile only, best-effort) ──
  // NOTE: Intentionally deferred off the pre-runApp path. Serious Python's
  // first launch does heavy native asset extraction and lib loading; running it
  // here (before the Activity is fully resumed / before runApp) is what crashed
  // the app on cold installs. It is instead booted lazily the first time the
  // SIDE IDE actually uses offline mode (OfflinePythonService.start()).
  // Kept here only as a lightweight log hook; no work is performed.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS)) {
    debugPrint('🏛️ Offline Python warm-up deferred to first offline use');
  }

  // NOTE: All Activity-dependent services (permissions, CallKit, AudioService,
  // LocalNotifications, Geolocator) are initialized in StarlightEngineGate
  // _initEngine() where the Activity is alive and ready.

  runApp(const StarlightApp());
}

class StarlightApp extends StatefulWidget {
  const StarlightApp({super.key});

  @override
  State<StarlightApp> createState() => _StarlightAppState();
}

class _StarlightAppState extends State<StarlightApp> {
  @override
  void initState() {
    super.initState();
    themeController.loadStoredTheme();
    themeController.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: themeController.themeMode,

      initialRoute: AppRoutes.engine,

      // 2. Add this to handle named route generation
      onGenerateRoute: AppRoutes.generateRoute,

      // 1. Start with animated splash screen
      home: const AnimatedSplashScreen(),

      // 2. CONNECT THE ROUTES MAP:
      // This tells Flutter: "If the Router says go to '/intro-screen',
      // look in AppRoutes.routes to find the Widget."

      // 3. SAFETY NET: Handle missing route calls gracefully
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text("🏛️ Route Error: ${settings.name} not found"),
            ),
          ),
        );
      },
    );
  }
}

class StarlightEngineGate extends StatefulWidget {
  const StarlightEngineGate({super.key});

  @override
  State<StarlightEngineGate> createState() => _StarlightEngineGateState();
}

class _StarlightEngineGateState extends State<StarlightEngineGate>
    with WidgetsBindingObserver {
  bool _isRouting = false;
  bool _showBiometricLock = false;
  bool _lockOverlayPresented = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricLockAndInit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-lock when the app goes to the background: a second person must not be
  /// able to pick up an already-unlocked app. The lock is presented as a
  /// full-screen route pushed on top of whatever is currently shown.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _reLockForBackground();
    }
  }

  Future<void> _reLockForBackground() async {
    try {
      final enabled =
          await StarlightStorage.getBiometricLockEnabled();
      if (!mounted) return;
      if (enabled && !_showBiometricLock) {
        await _presentLockOverlay();
      }
    } catch (_) {
      // If we cannot read lock state, fail closed: present the lock anyway.
      if (mounted) await _presentLockOverlay();
    }
  }

  Future<void> _presentLockOverlay() async {
    if (_lockOverlayPresented || !mounted) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _lockOverlayPresented = true;

    // Small delay so the navigator is stable enough to push on top.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) {
      _lockOverlayPresented = false;
      return;
    }
    final currentNav = navigatorKey.currentState;
    if (currentNav == null) {
      _lockOverlayPresented = false;
      return;
    }

    currentNav.push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => BiometricLockScreen(
          onUnlock: () {
            // Unlock for the background re-lock: just dismiss the overlay and
            // record the fresh auth time. The engine-gate launch flag is left
            // untouched (it governs display of the lock on cold launch).
            _lockOverlayPresented = false;
            if (currentNav.canPop()) currentNav.pop();
            StarlightStorage.setLastAuthTime(
              DateTime.now().millisecondsSinceEpoch,
            );
          },
        ),
      ),
    );
  }

  Future<void> _checkBiometricLockAndInit() async {
    // 🏛️ Check if biometric lock is enabled
    final biometricLockEnabled = await StarlightStorage.getBiometricLockEnabled();
    
    if (biometricLockEnabled) {
      // Check if enough time has passed since last auth (optional timeout)
      final lastAuthTime = await StarlightStorage.getLastAuthTime();
      final timeoutMinutes = await StarlightStorage.getAppLockTimeout() ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final elapsedMinutes = (currentTime - lastAuthTime) / (1000 * 60);
      
      // If timeout is set and not elapsed, skip biometric lock
      if (timeoutMinutes > 0 && elapsedMinutes < timeoutMinutes) {
        _initEngine();
        return;
      }
      
      // Show biometric lock
      if (mounted) {
        setState(() => _showBiometricLock = true);
      }
    } else {
      _initEngine();
    }
  }

  void _handleBiometricUnlock() {
    setState(() => _showBiometricLock = false);
    _initEngine();
  }

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  /// Phase A: Activity-dependent services that MUST run after the widget tree
  /// is built (Activity is alive). These were moved out of `main()` because
  /// `permission_handler`, `flutter_callkit_incoming`, `audio_service`, and
  /// `flutter_local_notifications` all require a live Activity.
  Future<void> _initActivityServices() async {
    // ── Permissions (mobile only — permission_handler is Android/iOS only) ──
    if (_isMobile) {
      debugPrint("🏛️ Engine: Phase A1 — App permissions");
      try {
        await requestAppPermissions();
      } catch (e) {
        debugPrint("🏛️ Engine: App permissions error (non-fatal): $e");
      }
    }
    // try {
    //   await requestP2PPermissions();
    // } catch (e) {
    //   debugPrint("🏛️ Engine: P2P permissions error (non-fatal): $e");
    // }

    // ── CallKitService (needs Activity for notification permission) ──
    if (_isMobile) {
      debugPrint("🏛️ Engine: Phase A2 — CallKitService");
      try {
        // Set global navigator key for CallKit navigation
        globalNavigatorKey = navigatorKey;
        await CallKitService.instance.initialize();
        debugPrint('🏛️ CallKitService initialized');
      } catch (e) {
        debugPrint('🏛️ CallKitService init error (non-fatal): $e');
      }
    }

    // ── Local notifications ──
    if (_isMobile) {
      debugPrint("🏛️ Engine: Phase A3 — ChatLocalNotificationService");
      try {
        await ChatLocalNotificationService.instance.initialize();
        debugPrint('🏛️ ChatLocalNotificationService initialized');
      } catch (e) {
        debugPrint('🏛️ ChatLocalNotificationService init error (non-fatal): $e');
      }
    }

    // ── Audio service (needs Activity + FlutterEngine for media notification) ──
    if (_isMobile) {
      debugPrint("🏛️ Engine: Phase A4 — AudioPlaybackService");
      try {
        await AudioPlaybackService.init();
        debugPrint('🏛️ AudioPlaybackService initialized');
      } catch (e) {
        debugPrint('🏛️ AudioPlaybackService init error (non-fatal): $e');
      }
    }

    // ── Media transfer notifications ──
    if (_isMobile) {
      debugPrint("🏛️ Engine: Phase A5 — MediaTransferService");
      try {
        await MediaTransferService.instance.init();
        debugPrint('🏛️ MediaTransferService initialized');
      } catch (e) {
        debugPrint('🏛️ MediaTransferService init error (non-fatal): $e');
      }
    }

    // ── Alarm scheduler (uses flutter_local_notifications + alarm plugin) ──
    if (_isMobile) {
      debugPrint("🏛️ Engine: Phase A6 — LocalAlarmScheduler");
      try {
        await LocalAlarmScheduler.init();
        await LocalAlarmScheduler.rescheduleAll();
        debugPrint('🏛️ LocalAlarmScheduler initialized');
      } catch (e) {
        debugPrint('🏛️ LocalAlarmScheduler init error (non-fatal): $e');
      }
    }

    // ── Global audio notification (video directory) ──
    if (_isMobile) {
      debugPrint("🏛️ Engine: Phase A7 — GlobalAudioNotificationService");
      try {
        await GlobalAudioNotificationService.instance.init();
        debugPrint('🏛️ GlobalAudioNotificationService initialized');
      } catch (e) {
        debugPrint('🏛️ GlobalAudioNotificationService init error (non-fatal): $e');
      }
    }

    // ── Missed task check ──
    debugPrint("🏛️ Engine: Phase A8 — Missed task check");
    try {
      final due = await TaskService.getDueTasks();
      for (final task in due) {
        debugPrint('🏛️ Missed due task: ${task.title}');
        await TaskService.markNotified(task.id);
      }
    } catch (e) {
      debugPrint('🏛️ Missed task check error (non-fatal): $e');
    }
  }

  Future<void> _initEngine() async {
    if (_isRouting) return;
    _isRouting = true;

    try {
      // ── Step 1: Ensure Firebase is alive (safety net for hot restart / failed main init) ──
      debugPrint("🏛️ Engine: Step 1 — Firebase safety check");
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          debugPrint("🏛️ Engine: Firebase Core initialized (safety net)");
        } catch (e) {
          debugPrint("🏛️ Engine: CRITICAL — Firebase failed to initialize: $e");
        }
      } else {
        debugPrint("🏛️ Engine: Firebase already initialized (${Firebase.apps.length} app(s))");
      }

      // ── Step 2: FirebaseMessaging permission (mobile only) ──
      debugPrint("🏛️ Engine: Step 2 — FirebaseMessaging permission");
      if (_isMobile) {
        try {
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.getNotificationSettings();
          debugPrint("🏛️ Engine: Notification status: ${settings.authorizationStatus}");

          if (settings.authorizationStatus != AuthorizationStatus.authorized) {
            final newSettings = await messaging.requestPermission(
              alert: true, badge: true, sound: true, provisional: false,
            );
            if (newSettings.authorizationStatus == AuthorizationStatus.denied) {
              debugPrint("🏛️ Engine: FCM Permission Denied. Terminating...");
              if (defaultTargetPlatform == TargetPlatform.android) {
                await SystemNavigator.pop();
              } else {
                exit(0);
              }
              return;
            }
          }
        } catch (e) {
          debugPrint("🏛️ Engine: FirebaseMessaging error (non-fatal): $e");
        }
      } else {
        debugPrint("🏛️ Engine: FirebaseMessaging skipped on ${defaultTargetPlatform.name}");
      }

      // ── Step 3: Activity-dependent services (moved from main) ──
      debugPrint("🏛️ Engine: Step 3 — Activity-dependent services");
      await _initActivityServices();

      // ── Step 4: Location permission ──
      debugPrint("🏛️ Engine: Step 4 — Location permission");
      final _locationSupported = _isMobile ||
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);
      if (_locationSupported) {
        try {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          debugPrint('🏛️ Location: services enabled = $serviceEnabled');

          var permission = await Geolocator.checkPermission();
          debugPrint('🏛️ Location: permission status = $permission');

          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            debugPrint('🏛️ Location: after request = $permission');
          }

          if (_isMobile) {
            if (permission == LocationPermission.deniedForever) {
              debugPrint('🏛️ Location: DENIED FOREVER');
            } else if (permission == LocationPermission.whileInUse ||
                       permission == LocationPermission.always) {
              debugPrint('🏛️ Location: GRANTED ($permission)');
            }
          } else {
            // Windows has no runtime location prompt, so inform the user with
            // a snackbar mirroring the Android launch-time permission flow.
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              final messenger = ScaffoldMessenger.of(ctx);
              SnackBar snackbar;
              if (!serviceEnabled) {
                snackbar = SnackBar(
                  content: const Text('Location services are off. Turn them on to use location features.'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () => Geolocator.openLocationSettings(),
                  ),
                );
              } else if (permission == LocationPermission.denied ||
                         permission == LocationPermission.deniedForever) {
                snackbar = SnackBar(
                  content: const Text('Location permission is denied. Enable it to update your location.'),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Settings',
                    textColor: Colors.white,
                    onPressed: () => Geolocator.openAppSettings(),
                  ),
                );
              } else {
                snackbar = SnackBar(
                  content: const Text('Location access granted. Update your location from the Portfolio.'),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                );
              }
              messenger.showSnackBar(snackbar);
            }
          }
        } catch (e) {
          debugPrint('🏛️ Location: permission check failed — $e');
        }
      }

      // ── Step 5: SetupService (non-blocking — failure must not prevent routing) ──
      debugPrint("🏛️ Engine: Step 5 — SetupService");
      try {
        final token = await StarlightStorage.getUserToken();
        if (token != null && token.isNotEmpty) {
          final setupResult = await SetupService().performInitialSetup();
          debugPrint('🏛️ SetupService: success=${setupResult['success']}');
        } else {
          debugPrint('🏛️ SetupService: skipped (no token)');
        }
      } catch (e) {
        debugPrint('🏛️ SetupService error (non-fatal): $e');
      }

      // ── Step 6: FCM Service ──
      debugPrint("🏛️ Engine: Step 6 — FCM Service");
      try {
        final fcmContext = navigatorKey.currentContext;
        if (fcmContext != null) {
          await FCMService().initialize(fcmContext);
          debugPrint('🏛️ FCM Service: Initialized');
        } else {
          debugPrint('🏛️ FCM Service: context not ready, skipping');
        }
      } catch (e) {
        debugPrint('🏛️ FCM Service error (non-fatal): $e');
      }

      // ── Step 6b: Dashboard Sync Service ──
      debugPrint("🏛️ Engine: Step 6b — Dashboard Sync Service");
      try {
        DashboardSyncService.instance.init();
        debugPrint('🏛️ DashboardSync: Initialized');
      } catch (e) {
        debugPrint('🏛️ DashboardSync error (non-fatal): $e');
      }

      // ── Step 7: Minimum splash duration (loading screen has been showing since AnimatedSplashScreen) ──
      debugPrint("🏛️ Engine: Step 7 — Waiting before routing...");
      await Future.delayed(const Duration(seconds: 2));

      // ── Step 8: Route user (this is where the loading screen is removed) ──
      debugPrint("🏛️ Engine: Step 8 — Routing user");
      final context = navigatorKey.currentContext;
      if (context != null) {
        await UniversalRouter.routeUser(context);
        debugPrint('🏛️ Engine: Routing completed');

        // Handle pending call data from killed-state notification
        if (_pendingCallData != null) {
          debugPrint('🏛️ Processing pending call data');
          _handleCallNotification(_pendingCallData!);
          _pendingCallData = null;
        }
      } else {
        debugPrint("🏛️ Engine: Navigator context not ready — retrying in 1s");
        await Future.delayed(const Duration(seconds: 1));
        final retryCtx = navigatorKey.currentContext;
        if (retryCtx != null) {
          await UniversalRouter.routeUser(retryCtx);
          debugPrint('🏛️ Engine: Retry routing completed');
        } else {
          debugPrint("🏛️ Engine: Retry failed — context still null");
        }
      }
    } catch (e) {
      debugPrint("🏛️ Fatal Engine Error: $e");
      debugPrint("🏛️ Stacktrace: ${e is Error ? e.stackTrace : ''}");
    } finally {
      _isRouting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🏛️ Show biometric lock screen if enabled and not authenticated
    if (_showBiometricLock) {
      return BiometricLockScreen(onUnlock: _handleBiometricUnlock);
    }
    
    return const StarlightLoading();
  }
}
