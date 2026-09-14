import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../models/book_models.dart';
import 'library_service.dart';
import '../../core/ads_setup.dart';

class LibraryAdService {
  static Timer? _dwellTimer;
  static bool _viewRecorded = false;
  static bool _adShown = false;

  static void reset() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _viewRecorded = false;
    _adShown = false;
  }

  static void startDwellTimer(String bookId, void Function(int views) onViewRecorded) {
    _dwellTimer?.cancel();
    _viewRecorded = false;
    _dwellTimer = Timer(const Duration(seconds: 15), () async {
      if (_viewRecorded) return;
      _viewRecorded = true;
      try {
        final res = await LibraryService.recordView(bookId);
        onViewRecorded(res['views_count'] ?? 0);
      } catch (_) {}
    });
  }

  static void cancelDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
  }

  static Future<bool> showRewardAd(BuildContext context) async {
    if (_adShown) return true;
    _adShown = true;

    debugPrint('📱 [LibraryAdService] Showing rewarded ad for content access.');

    final completer = Completer<bool>();

    if (!AdConfig.isInitialized) {
      debugPrint('📱 [LibraryAdService] Ads not initialized, showing fallback dialog.');
      _showFallbackDialog(context, completer);
      return completer.future;
    }

    await RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('📱 [LibraryAdService] Rewarded ad loaded, showing to user.');

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('📱 [LibraryAdService] Rewarded ad dismissed.');
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('📱 [LibraryAdService] Rewarded ad failed: ${error.message}');
              ad.dispose();
              if (!completer.isCompleted) {
                _showFallbackDialog(context, completer);
              }
            },
          );

          ad.show(
            onUserEarnedReward: (ad, reward) {
              debugPrint('📱 [LibraryAdService] User earned reward: ${reward.amount} ${reward.type}');
              if (!completer.isCompleted) completer.complete(true);
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('📱 [LibraryAdService] Rewarded ad load failed: ${error.message}');
          _showFallbackDialog(context, completer);
        },
      ),
    );

    return completer.future;
  }

  static void _showFallbackDialog(BuildContext context, Completer<bool> completer) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111428),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_filled, color: Colors.amber, size: 64),
            const SizedBox(height: 16),
            const Text(
              "Watch a short ad to support the creator?",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Ad unavailable — tap Continue for access",
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  completer.complete(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Continue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BannerAdPlaceholder extends StatefulWidget {
  final double height;
  const BannerAdPlaceholder({super.key, this.height = 60});

  @override
  State<BannerAdPlaceholder> createState() => _BannerAdPlaceholderState();
}

class _BannerAdPlaceholderState extends State<BannerAdPlaceholder> {
  BannerAd? _bannerAd;
  bool _adLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (!AdConfig.isInitialized) return;

    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: AdSize.fluid,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('📱 [Banner] Banner ad loaded.');
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('📱 [Banner] Banner ad failed: ${error.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adLoaded && _bannerAd != null) {
      return Container(
        height: widget.height,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ads_click, color: Colors.grey.shade500, size: 16),
          const SizedBox(width: 6),
          Text("Ad Banner", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
