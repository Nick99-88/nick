import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/storage.dart';
import '../../services/subscription/subscription_service.dart';

class WalletMeter extends StatefulWidget {
  final bool showSubscriptions;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const WalletMeter({
    super.key,
    this.showSubscriptions = true,
    this.onTap,
    this.padding,
  });

  @override
  State<WalletMeter> createState() => WalletMeterState();
}

class WalletMeterState extends State<WalletMeter> with SingleTickerProviderStateMixin {
  int _gold = 0;
  int _silver = 0;
  int _aiCredits = 0;
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Animated display values for smooth counting
  double _displayGold = 0;
  double _displaySilver = 0;
  double _displayAi = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _loadFromCache();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    final cached = await StarlightStorage.getCachedWallet();
    if (!mounted) return;
    setState(() {
      _gold = cached['gold'] ?? 0;
      _silver = cached['silver'] ?? 0;
      _aiCredits = cached['ai_credits'] ?? 0;
      _subscriptions = cached['subscriptions'] ?? [];
      _displayGold = _gold.toDouble();
      _displaySilver = _silver.toDouble();
      _displayAi = _aiCredits.toDouble();
      _isLoading = false;
    });
  }

  /// Sync with backend — called on app launch, after transactions, etc.
  Future<void> syncWithServer() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final service = SubscriptionService();
      final data = await service.fetchAndCacheWalletSummary();
      if (!mounted) return;

      final newGold = data['gold_coins'] ?? 0;
      final newSilver = data['silver_coins'] ?? 0;
      final newAi = data['ai_credits'] ?? 0;
      final newSubs = data['active_subscriptions'] != null
          ? List<Map<String, dynamic>>.from(data['active_subscriptions'])
          : <Map<String, dynamic>>[];

      // Animate from current display to new values
      _animateToValues(newGold.toDouble(), newSilver.toDouble(), newAi.toDouble());

      setState(() {
        _gold = newGold;
        _silver = newSilver;
        _aiCredits = newAi;
        _subscriptions = newSubs;
      });
    } catch (e) {
      print("WalletMeter: sync failed: $e");
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Show subtraction animation then sync with server
  Future<void> deductAndSync({required int gold, int silver = 0, int aiCredits = 0}) async {
    // Immediately animate subtraction from display
    final targetGold = _displayGold - gold;
    final targetSilver = _displaySilver - silver;
    final targetAi = _displayAi - aiCredits;

    _animateToValues(
      targetGold < 0 ? 0 : targetGold,
      targetSilver < 0 ? 0 : targetSilver,
      targetAi < 0 ? 0 : targetAi,
    );

    // Update cache optimistically
    await StarlightStorage.cacheWalletData(
      gold: targetGold < 0 ? 0 : targetGold.toInt(),
      silver: targetSilver < 0 ? 0 : targetSilver.toInt(),
      aiCredits: targetAi < 0 ? 0 : targetAi.toInt(),
      subscriptions: _subscriptions,
    );

    setState(() {
      _gold = targetGold < 0 ? 0 : targetGold.toInt();
      _silver = targetSilver < 0 ? 0 : targetSilver.toInt();
      _aiCredits = targetAi < 0 ? 0 : targetAi.toInt();
    });

    // Then sync real values from backend
    await Future.delayed(const Duration(milliseconds: 600));
    await syncWithServer();
  }

  void _animateToValues(double targetGold, double targetSilver, double targetAi) {
    final duration = const Duration(milliseconds: 500);
    final goldStart = _displayGold;
    final silverStart = _displaySilver;
    final aiStart = _displayAi;
    final startTime = DateTime.now();

    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final progress = (elapsed / duration.inMilliseconds).clamp(0.0, 1.0);
      final eased = 1 - (1 - progress) * (1 - progress); // ease-out quad

      setState(() {
        _displayGold = goldStart + (targetGold - goldStart) * eased;
        _displaySilver = silverStart + (targetSilver - silverStart) * eased;
        _displayAi = aiStart + (targetAi - aiStart) * eased;
      });

      if (progress >= 1.0) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Center(
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap ?? () => syncWithServer(),
      child: Container(
        padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.withOpacity(0.08),
              Colors.purple.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildCurrencyChip(
                  emoji: '\u{1F947}',
                  value: _displayGold.toInt(),
                  color: const Color(0xFFFFD700),
                ),
                const SizedBox(width: 8),
                _buildCurrencyChip(
                  emoji: '\u{26AA}',
                  value: _displaySilver.toInt(),
                  color: const Color(0xFFC0C0C0),
                ),
                const SizedBox(width: 8),
                _buildCurrencyChip(
                  emoji: '\u{2728}',
                  value: _displayAi.toInt(),
                  color: const Color(0xFFA855F7),
                ),
                const Spacer(),
                if (_isSyncing)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.amber),
                  )
                else
                  Icon(Icons.refresh_rounded, color: Colors.white.withOpacity(0.3), size: 16),
              ],
            ),
            if (widget.showSubscriptions && _subscriptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 24,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _subscriptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (ctx, i) {
                    final sub = _subscriptions[i];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: Colors.green, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            sub['title'] ?? sub['product_id'] ?? '',
                            style: const TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyChip({required String emoji, required int value, required Color color}) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnimation.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
