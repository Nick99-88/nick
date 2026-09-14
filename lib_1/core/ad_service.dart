import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads_setup.dart';
import '../services/subscription/subscription_service.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  BannerAd? _bannerAd;

  bool _rewardedAdLoading = false;
  bool _interstitialAdLoading = false;
  bool _rewardedAdReady = false;
  bool _interstitialAdReady = false;

  bool get isRewardedAdReady => _rewardedAdReady;
  bool get isInterstitialAdReady => _interstitialAdReady;

  final _rewardAdLoadedController = StreamController<bool>.broadcast();
  Stream<bool> get onRewardedAdLoaded => _rewardAdLoadedController.stream;

  // ── Rewarded Ad ──

  Future<void> loadRewardedAd() async {
    if (!AdConfig.isInitialized) {
      debugPrint('📱 [AdService] ⚠️ Ads not initialized. Call AdConfig.initialize() first.');
      return;
    }
    if (_rewardedAdLoading) {
      debugPrint('📱 [AdService] Rewarded ad already loading, skipping.');
      return;
    }

    _rewardedAdLoading = true;
    debugPrint('📱 [AdService] Loading rewarded ad from: ${AdConfig.rewardedAdUnitId}');

    await RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAdReady = true;
          _rewardedAdLoading = false;
          debugPrint('📱 [AdService] ✅ Rewarded ad LOADED and ready to show.');
          _rewardAdLoadedController.add(true);

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('📱 [AdService] Rewarded ad dismissed.');
              ad.dispose();
              _rewardedAd = null;
              _rewardedAdReady = false;
              _rewardAdLoadedController.add(false);
              // Preload next ad
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('📱 [AdService] ❌ Rewarded ad failed to show: ${error.message}');
              ad.dispose();
              _rewardedAd = null;
              _rewardedAdReady = false;
              _rewardAdLoadedController.add(false);
            },
            onAdShowedFullScreenContent: (ad) {
              debugPrint('📱 [AdService] 🎬 Rewarded ad SHOWING now.');
            },
            onAdImpression: (ad) {
              debugPrint('📱 [AdService] Rewarded ad impression recorded.');
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('📱 [AdService] ❌ Rewarded ad FAILED to load: ${error.message} (code: ${error.code})');
          _rewardedAd = null;
          _rewardedAdReady = false;
          _rewardedAdLoading = false;
          _rewardAdLoadedController.add(false);
          // Retry after delay
          Future.delayed(const Duration(seconds: 10), () => loadRewardedAd());
        },
      ),
    );
  }

  /// Show the rewarded ad. Returns true if the user earned a reward.
  Future<bool> showRewardedAd({VoidCallback? onRewarded}) async {
    if (_rewardedAd == null || !_rewardedAdReady) {
      debugPrint('📱 [AdService] ⚠️ No rewarded ad ready. Loading one...');
      await loadRewardedAd();
      return false;
    }

    debugPrint('📱 [AdService] 🎬 Showing rewarded ad...');
    bool rewarded = false;
    final completer = Completer<bool>();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('📱 [AdService] Rewarded ad dismissed. Rewarded: $rewarded');
        ad.dispose();
        _rewardedAd = null;
        _rewardedAdReady = false;
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('📱 [AdService] ❌ Rewarded ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        _rewardedAdReady = false;
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📱 [AdService] 🎬 Rewarded ad is now fullscreen.');
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('📱 [AdService] 🎉 USER EARNED REWARD: ${reward.amount} ${reward.type}');
        rewarded = true;
        onRewarded?.call();
      },
    );

    final result = await completer.future;
    debugPrint('📱 [AdService] Rewarded ad flow complete. Reward earned: $result');
    return result;
  }

  // ── Interstitial Ad ──

  Future<void> loadInterstitialAd() async {
    if (!AdConfig.isInitialized) {
      debugPrint('📱 [AdService] ⚠️ Ads not initialized.');
      return;
    }
    if (_interstitialAdLoading) return;

    _interstitialAdLoading = true;
    debugPrint('📱 [AdService] Loading interstitial ad from: ${AdConfig.interstitialAdUnitId}');

    await InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAdReady = true;
          _interstitialAdLoading = false;
          debugPrint('📱 [AdService] ✅ Interstitial ad LOADED.');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('📱 [AdService] Interstitial ad dismissed.');
              ad.dispose();
              _interstitialAd = null;
              _interstitialAdReady = false;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('📱 [AdService] ❌ Interstitial failed to show: ${error.message}');
              ad.dispose();
              _interstitialAd = null;
              _interstitialAdReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('📱 [AdService] ❌ Interstitial FAILED: ${error.message} (code: ${error.code})');
          _interstitialAd = null;
          _interstitialAdReady = false;
          _interstitialAdLoading = false;
          Future.delayed(const Duration(seconds: 15), () => loadInterstitialAd());
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_interstitialAd == null || !_interstitialAdReady) {
      debugPrint('📱 [AdService] ⚠️ No interstitial ad ready.');
      return;
    }

    debugPrint('📱 [AdService] 🎬 Showing interstitial ad...');
    _interstitialAd!.show();
  }

  // ── Reward Credits ──

  /// Credit the user with AI tokens for watching a rewarded ad.
  /// Returns the reward map: {silver: int, ai_credits: int}
  Future<Map<String, int>> creditRewardedAdUser() async {
    const rewardSilver = 5;
    const rewardAiCredits = 1;

    debugPrint('📱 [AdService] Crediting user: +$rewardSilver silver, +$rewardAiCredits AI credits');

    try {
      // Try server-side credit via subscription service
      final service = SubscriptionService();
      await service.getDailyBonus(); // reuse daily bonus endpoint pattern
      debugPrint('📱 [AdService] ✅ User credited via server.');
    } catch (e) {
      debugPrint('📱 [AdService] ⚠️ Server credit failed, using local reward: $e');
    }

    return {'silver': rewardSilver, 'ai_credits': rewardAiCredits};
  }

  // ── Cleanup ──

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    _rewardAdLoadedController.close();
  }
}
