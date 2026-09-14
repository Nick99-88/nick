import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/library_service.dart';
import '../../core/ads_setup.dart';

class LibraryAdOverlay extends StatefulWidget {
  final Widget child;
  final String bookId;
  final bool showAds;

  const LibraryAdOverlay({
    super.key,
    required this.child,
    required this.bookId,
    required this.showAds,
  });

  @override
  State<LibraryAdOverlay> createState() => _LibraryAdOverlayState();
}

class _LibraryAdOverlayState extends State<LibraryAdOverlay> {
  Timer? _adTimer;
  bool _showAdNow = false;
  bool _initialAdShown = false;
  RewardedAd? _currentAd;
  bool _adLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.showAds) {
      _showInitialAd();
    }
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    _currentAd?.dispose();
    super.dispose();
  }

  void _showInitialAd() {
    _showAdNow = true;
    _initialAdShown = true;
    _loadAdForOverlay();
  }

  void _loadAdForOverlay() {
    if (!AdConfig.isInitialized) {
      setState(() => _adLoading = false);
      return;
    }

    setState(() => _adLoading = true);

    RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _currentAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _currentAd = null;
              _dismissAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _currentAd = null;
              _dismissAd();
            },
          );
          if (mounted) setState(() => _adLoading = false);
          ad.show(
            onUserEarnedReward: (ad, reward) {
              debugPrint('📱 [AdOverlay] Reward earned: ${reward.amount}');
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('📱 [AdOverlay] Ad load failed: ${error.message}');
          if (mounted) setState(() => _adLoading = false);
        },
      ),
    );
  }

  void _startAdTimer() {
    _adTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) {
        _showAdNow = true;
        _loadAdForOverlay();
      }
    });
  }

  void _dismissAd() {
    setState(() => _showAdNow = false);
    if (_initialAdShown) {
      _initialAdShown = false;
      _startAdTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showAdNow)
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.85),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.play_circle_fill, size: 48, color: Colors.amber),
                            const SizedBox(height: 12),
                            const Text(
                              "Advertisement",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            if (_adLoading)
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(strokeWidth: 3),
                                      SizedBox(height: 12),
                                      Text("Loading ad...", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.ad_units, size: 40, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    const Text("Ad completed", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: _dismissAd,
                                      child: const Text("Close", style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            if (_adLoading)
                              const SizedBox(
                                height: 40,
                                child: Center(
                                  child: Text("Please wait...", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: ElevatedButton(
                                  onPressed: _dismissAd,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                  child: const Text("Continue Reading", style: TextStyle(color: Colors.white)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _initialAdShown ? "Support creators by watching ads" : "Ad break - next ad in 10 minutes",
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Helper to check access and navigate with ad overlay
Future<void> openDocumentWithAds({
  required BuildContext context,
  required WidgetBuilder documentBuilder,
  required String bookId,
}) async {
  try {
    final access = await LibraryService.getBookAccess(bookId);
    if (!context.mounted) return;
    final showAds = access['show_ads'] == true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryAdOverlay(
          bookId: bookId,
          showAds: showAds,
          child: documentBuilder(context),
        ),
      ),
    );
  } catch (_) {
    // Fallback: open without ads
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: documentBuilder));
    }
  }
}
