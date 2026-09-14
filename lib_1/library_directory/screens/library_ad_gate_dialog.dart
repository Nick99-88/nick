import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/theme.dart';
import '../../core/ads_setup.dart';

class AdGateDialog extends StatefulWidget {
  const AdGateDialog({super.key});

  @override
  State<AdGateDialog> createState() => _AdGateDialogState();
}

class _AdGateDialogState extends State<AdGateDialog> {
  bool _loading = true;
  bool _adFailed = false;

  @override
  void initState() {
    super.initState();
    _showAd();
  }

  void _showAd() {
    if (!AdConfig.isInitialized) {
      setState(() {
        _loading = false;
        _adFailed = true;
      });
      return;
    }

    RewardedAd.load(
      adUnitId: AdConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (mounted) Navigator.pop(context, false);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (mounted) {
                setState(() => _adFailed = true);
                _loading = false;
              }
            },
          );
          setState(() => _loading = false);
          ad.show(
            onUserEarnedReward: (ad, reward) {
              debugPrint('📱 [AdGateDialog] Reward earned: ${reward.amount} ${reward.type}');
              ad.dispose();
              if (mounted) Navigator.pop(context, true);
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('📱 [AdGateDialog] Ad load failed: ${error.message}');
          if (mounted) {
            setState(() {
              _adFailed = true;
              _loading = false;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: StarlightTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Loading advertisement...",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Ad failed or unavailable — show manual continue
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_fill, size: 48, color: Colors.amber),
            const SizedBox(height: 12),
            const Text(
              "Advertisement",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "Ad unavailable. Tap Continue to proceed.",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StarlightTheme.primaryBlue,
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
