import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConfig {
  AdConfig._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  // ── Android Test Ad Unit IDs ──
  static String get _androidAppId => 'ca-app-pub-3940256099942544~3347511713';
  static String get _androidBannerId => 'ca-app-pub-3940256099942544/6300978111';
  static String get _androidInterstitialId => 'ca-app-pub-3940256099942544/1033173712';
  static String get _androidRewardedId => 'ca-app-pub-3940256099942544/5224354917';

  // ── iOS Test Ad Unit IDs ──
  static String get _iosAppId => 'ca-app-pub-3940256099942544~1458002511';
  static String get _iosBannerId => 'ca-app-pub-3940256099942544/2934735716';
  static String get _iosInterstitialId => 'ca-app-pub-3940256099942544/4411468910';
  static String get _iosRewardedId => 'ca-app-pub-3940256099942544/1712485313';

  // ── Platform-aware getters ──
  static String get appId => Platform.isAndroid ? _androidAppId : _iosAppId;
  static String get bannerAdUnitId => Platform.isAndroid ? _androidBannerId : _iosBannerId;
  static String get interstitialAdUnitId => Platform.isAndroid ? _androidInterstitialId : _iosInterstitialId;
  static String get rewardedAdUnitId => Platform.isAndroid ? _androidRewardedId : _iosRewardedId;

  static String get platform => Platform.isAndroid ? 'Android' : 'iOS';

  /// Initialize the Google Mobile Ads SDK.
  /// Call this once in main() before runApp().
  static Future<bool> initialize() async {
    if (_initialized) {
      debugPrint('📱 [AdConfig] Already initialized, skipping.');
      return true;
    }

    debugPrint('📱 [AdConfig] ─────────────────────────────────────');
    debugPrint('📱 [AdConfig] Initializing Google Mobile Ads SDK...');
    debugPrint('📱 [AdConfig] Platform: $platform');
    debugPrint('📱 [AdConfig] App ID: $appId');
    debugPrint('📱 [AdConfig] Banner Ad Unit: $bannerAdUnitId');
    debugPrint('📱 [AdConfig] Interstitial Ad Unit: $interstitialAdUnitId');
    debugPrint('📱 [AdConfig] Rewarded Ad Unit: $rewardedAdUnitId');
    debugPrint('📱 [AdConfig] ─────────────────────────────────────');

    try {
      // Set test device IDs so physical devices get test ads
      final testDeviceIds = <String>[];
      RequestConfiguration configuration = RequestConfiguration(
        testDeviceIds: testDeviceIds,
        maxAdContentRating: MaxAdContentRating.g,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
      );
      await MobileAds.instance.updateRequestConfiguration(configuration);
      debugPrint('📱 [AdConfig] Test device configuration applied.');

      // Initialize the SDK
      debugPrint('📱 [AdConfig] Calling MobileAds.instance.initialize()...');
      final initStatus = await MobileAds.instance.initialize();
      debugPrint('📱 [AdConfig] SDK initialized successfully.');

      // Log adapter status for each ad format
      if (initStatus.adapterStatuses.isNotEmpty) {
        debugPrint('📱 [AdConfig] Adapter statuses:');
        for (final entry in initStatus.adapterStatuses.entries) {
          debugPrint('📱 [AdConfig]   ${entry.key}: ${entry.value.state} '
              '(latency: ${(entry.value.latency * 1000).toStringAsFixed(0)}ms)');
          if (entry.value.description != null) {
            debugPrint('📱 [AdConfig]     desc: ${entry.value.description}');
          }
        }
      } else {
        debugPrint('📱 [AdConfig] No adapter statuses returned (normal for test ads).');
      }

      _initialized = true;
      debugPrint('📱 [AdConfig] ✅ Ad engine READY. Ads can now be loaded and shown.');
      debugPrint('📱 [AdConfig] ─────────────────────────────────────');
      return true;
    } catch (e, stack) {
      debugPrint('📱 [AdConfig] ❌ Initialization FAILED: $e');
      debugPrint('📱 [AdConfig] Stack: $stack');
      debugPrint('📱 [AdConfig] ─────────────────────────────────────');
      _initialized = false;
      return false;
    }
  }
}
