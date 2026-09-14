import 'package:flutter/material.dart';
import '../core/storage.dart';
import '../core/app_routes.dart';
import '../core/token_manager.dart';
import '../core/tabs_router.dart';

class UniversalRouter {
  static Future<void> routeUser(BuildContext context) async {
    try {
      // ── Gate 0: Language Selection ──
      final selectedLanguage = await StarlightStorage.getSelectedLanguage();
      if (selectedLanguage == null) {
        _go(context, AppRoutes.languageSelection);
        return;
      }

      // ── Gate 1: Intro ──
      final seenIntro = await StarlightStorage.getIntroToken();
      if (seenIntro != true) {
        _go(context, AppRoutes.intro);
        return;
      }

      // ── Gate 2: App Identity (Hardware Bind) ──
      final appId = await StarlightStorage.getAppId();
      if (appId == null || appId.isEmpty) {
        _go(context, AppRoutes.identityHub);
        return;
      }

      // ── Gate 2.5: Students Features - route directly to widget after login ──
      if (appId == 'starlight_student_portals') {
        var token = await StarlightStorage.getUserToken();
        if (token == null || token.isEmpty) {
          final rawToken = await StarlightStorage.getRawUserToken();
          if (rawToken != null && rawToken.isNotEmpty) {
            token = rawToken;
          } else {
            _go(context, AppRoutes.login);
            return;
          }
        }
        // If logged in, go directly to Students Features
        _go(context, AppRoutes.studentsFeatures);
        return;
      }

      // ── Gate 3: Auth Token ──
      var token = await StarlightStorage.getUserToken();
      if (token == null || token.isEmpty) {
        final rawToken = await StarlightStorage.getRawUserToken();
        if (rawToken != null && rawToken.isNotEmpty) {
          token = rawToken;
        } else {
          _go(context, AppRoutes.login);
          return;
        }
      }

      final bool isOffline = token == await StarlightStorage.getRawUserToken();

      // ── Gate 4: App Type Check ──
      final bool isInstitutional = appId == 'starlight_institution';

      if (!isInstitutional) {
        // ── Non-Institutional → route by app type ──
        final handled = await TabsRouter.route(context);
        if (handled) return;
        _go(context, AppRoutes.identityHub);
        return;
      }

      // ── Institutional → role-based routing ──

      // ── Step 1: Resolve role ──
      var role = await StarlightStorage.getUserRole();
      final bool roleMissing = role == null || role.isEmpty || role == 'user';

      if (roleMissing && !isOffline) {
        try {
          await TokenManager.instance.getValidToken();
          role = await StarlightStorage.getUserRole();
        } catch (_) {}
      }

      final bool stillDefault = role == null || role.isEmpty || role == 'user';
      if (stillDefault && !isOffline) {
        _go(context, AppRoutes.roleSelection);
        return;
      }

      role = role ?? 'user';

      // ── Step 2: Check identity by role ──
      final hasIdentity = await StarlightStorage.getIdentity();

      switch (role.toLowerCase()) {
        case 'owner':
          if (hasIdentity != true) {
            _go(context, AppRoutes.ownerIdentity);
          } else {
            _go(context, AppRoutes.dashboard);
          }
          return;

        case 'teacher':
          if (hasIdentity != true) {
            _go(context, AppRoutes.teacherIdentity);
          } else {
            _go(context, AppRoutes.socialPlatform);
          }
          return;

        case 'student':
          if (hasIdentity != true) {
            _go(context, AppRoutes.studentIdentity);
          } else {
            _go(context, AppRoutes.socialPlatform);
          }
          return;

        case 'staff':
          if (hasIdentity != true) {
            _go(context, AppRoutes.staffSetup);
          } else {
            _go(context, AppRoutes.socialPlatform);
          }
          return;

        case 'parent':
          if (hasIdentity != true) {
            _go(context, AppRoutes.parentIdentity);
          } else {
            final isLinked = await StarlightStorage.isParentChildLinked();
            _go(context, isLinked ? AppRoutes.parentDashboard : AppRoutes.childConnection);
          }
          return;

        default:
          _go(context, AppRoutes.roleSelection);
          return;
      }
    } catch (e) {
      debugPrint("🏛️ Router Critical Failure: $e");
      _go(context, AppRoutes.login);
    }
  }

  static void _go(BuildContext context, String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      debugPrint("🏛️ Router: Already at $routeName, skipping.");
      return;
    }
    debugPrint("🏛️ Router: $current → $routeName");
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }
}
