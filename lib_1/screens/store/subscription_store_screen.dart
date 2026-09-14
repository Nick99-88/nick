import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../../models/subscription_models.dart';
import '../../services/subscription/subscription_service.dart';
import '../../widgets/coin_display_widget.dart';

class SubscriptionStoreScreen extends StatefulWidget {
  const SubscriptionStoreScreen({super.key});

  @override
  State<SubscriptionStoreScreen> createState() => _SubscriptionStoreScreenState();
}

class _SubscriptionStoreScreenState extends State<SubscriptionStoreScreen>
    with TickerProviderStateMixin {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final TextEditingController _manualPKRController = TextEditingController();

  List<SubscriptionBundle> _bundles = [];
  List<SubscriptionBundle> _creditPacks = [];
  List<SubscriptionBundle> _subscriptions = [];
  List<String> _selectedBundles = [];
  UserWallet? _userWallet;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  bool _canClaimBonus = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualPKRController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final bundles = await _subscriptionService.getBundles();
      final wallet = await _subscriptionService.getUserWallet();
      final canClaimBonus = await _subscriptionService.canClaimDailyBonus();
      
      setState(() {
        _bundles = bundles;
        _creditPacks = bundles.where((b) => 
            b.durationDays <= 1 || b.name.toLowerCase().contains('pack')).toList();
        _subscriptions = bundles.where((b) => 
            b.durationDays > 1 && !b.name.toLowerCase().contains('pack')).toList();
        _userWallet = wallet;
        _canClaimBonus = canClaimBonus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      StarlightUtils.showErrorBox(context, 'Failed to load store data');
    }
  }

  void _toggleBundle(String bundleId) {
    setState(() {
      if (_selectedBundles.contains(bundleId)) {
        _selectedBundles.remove(bundleId);
      } else {
        _selectedBundles.add(bundleId);
      }
    });
  }

  Map<String, int> _calculateManualAmount() {
    final manualPKR = double.tryParse(_manualPKRController.text) ?? 0;
    if (manualPKR <= 0) return {'gold': 0, 'silver': 0, 'ai': 0};
    
    return {
      'gold': (manualPKR * 0.85).floor(),
      'silver': (manualPKR * 3).floor(),
      'ai': (manualPKR * 0.5).floor(),
    };
  }

  Map<String, dynamic> _calculateTotals() {
    final manualAmount = _calculateManualAmount();
    int totalGold = manualAmount['gold']!;
    int totalSilver = manualAmount['silver']!;
    int totalAi = manualAmount['ai']!;
    double totalPkr = double.tryParse(_manualPKRController.text) ?? 0;

    for (final bundleId in _selectedBundles) {
      final bundle = _bundles.firstWhere((b) => b.id == bundleId);
      totalPkr += bundle.priceGold;
      totalGold += bundle.priceGold.floor();
      totalSilver += bundle.features.grantSilver ?? 0;
      totalAi += bundle.features.aiCredits ?? 0;
    }

    return {
      'gold': totalGold,
      'silver': totalSilver,
      'ai': totalAi,
      'pkr': totalPkr,
    };
  }

  Future<void> _handlePayment() async {
    final totals = _calculateTotals();
    if (totals['pkr'] <= 0) {
      StarlightUtils.showErrorBox(context, 'Please select items to purchase');
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final paymentRequest = PaymentRequest(
        amount: totals['pkr'],
        currency: 'PKR',
        bundleIds: _selectedBundles,
        paymentMethod: 'google_pay',
        metadata: {
          'manual_amount': double.tryParse(_manualPKRController.text) ?? 0,
        },
      );

      final paymentResponse = await _subscriptionService.initiatePayment(paymentRequest);
      
      if (paymentResponse.checkoutUrl != null) {
        // In a real app, you would open the checkout URL
        StarlightUtils.showSuccessBox(context, 'Payment initiated successfully!');
        
        // For now, simulate successful payment
        await _simulateSuccessfulPayment(totals);
      }
    } catch (e) {
      StarlightUtils.showErrorBox(context, 'Payment failed: $e');
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _simulateSuccessfulPayment(Map<String, dynamic> totals) async {
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));
    
    // Update wallet (in real app, this would come from server)
    if (_userWallet != null) {
      setState(() {
        _userWallet = UserWallet(
          goldCoins: (_userWallet!.goldCoins + totals['gold']).toInt(),
          silverCoins: (_userWallet!.silverCoins + totals['silver']).toInt(),
          aiCredits: (_userWallet!.aiCredits + totals['ai']).toInt(),
          lastUpdated: DateTime.now(),
          transactions: [
            WalletTransaction(
              id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
              type: 'purchase',
              description: 'Store Purchase',
              goldAmount: totals['gold'] as int,
              silverAmount: totals['silver'] as int,
              aiCreditsAmount: totals['ai'] as int,
              createdAt: DateTime.now(),
              paymentMethod: 'google_pay',
            ),
            ...(_userWallet!.transactions ?? []),
          ],
        );
        _selectedBundles.clear();
        _manualPKRController.clear();
      });
    }
    
    StarlightUtils.showSuccessBox(context, 'Purchase successful!');
  }

  Future<void> _claimDailyBonus() async {
    try {
      final bonus = await _subscriptionService.getDailyBonus();
      final wallet = await _subscriptionService.getUserWallet();
      
      setState(() {
        _userWallet = UserWallet(
          goldCoins: wallet.goldCoins + bonus['gold']!,
          silverCoins: wallet.silverCoins + bonus['silver']!,
          aiCredits: wallet.aiCredits + bonus['ai_credits']!,
          lastUpdated: DateTime.now(),
          transactions: [
            WalletTransaction(
              id: 'bonus_${DateTime.now().millisecondsSinceEpoch}',
              type: 'bonus',
              description: 'Daily Visit Bonus',
              goldAmount: bonus['gold']!,
              silverAmount: bonus['silver']!,
              aiCreditsAmount: bonus['ai_credits']!,
              createdAt: DateTime.now(),
            ),
            ...(wallet.transactions ?? []),
          ],
        );
        _canClaimBonus = false;
      });
      
      StarlightUtils.showSuccessBox(context, 'Daily bonus claimed!');
    } catch (e) {
      StarlightUtils.showErrorBox(context, 'Failed to claim bonus');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Institution Vault',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_userWallet != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CoinDisplayWidget(wallet: _userWallet!),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Column(
              children: [
                // Bonus Banner
                _buildBonusBanner(),
                
                // Store Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCreditPacksTab(),
                      _buildSubscriptionsTab(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: totals['pkr'] > 0
          ? _buildPaymentBottomSheet(totals)
          : null,
    );
  }

  Widget _buildBonusBanner() {
    if (!_canClaimBonus) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withOpacity(0.2),
            Colors.orange.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Bonus Available!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Visit site daily to claim free coins',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _claimDailyBonus,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditPacksTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Quick Mint Section
          _buildQuickMintSection(),
          const SizedBox(height: 24),
          
          // Credit Packs Grid
          _buildBundlesGrid(_creditPacks),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildBundlesGrid(_subscriptions),
    );
  }

  Widget _buildQuickMintSection() {
    final totals = _calculateTotals();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.refresh, color: StarlightTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Quick Mint',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _manualPKRController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                  decoration: InputDecoration(
                    prefixText: 'Rs. ',
                    prefixStyle: const TextStyle(color: Colors.white, fontSize: 20),
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: StarlightTheme.primaryBlue.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: StarlightTheme.primaryBlue.withOpacity(0.3)),
                    ),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _buildCoinDisplay('Gold', totals['gold'], Colors.amber),
                    const SizedBox(width: 8),
                    _buildCoinDisplay('Silver', totals['silver'], Colors.grey),
                    const SizedBox(width: 8),
                    _buildCoinDisplay('AI', totals['ai'], StarlightTheme.primaryBlue),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinDisplay(String label, int amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              amount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBundlesGrid(List<SubscriptionBundle> bundles) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: bundles.length,
      itemBuilder: (context, index) {
        return _buildBundleCard(bundles[index]);
      },
    );
  }

  Widget _buildBundleCard(SubscriptionBundle bundle) {
    final isSelected = _selectedBundles.contains(bundle.id);
    
    return GestureDetector(
      onTap: () => _toggleBundle(bundle.id),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected 
              ? StarlightTheme.primaryBlue.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? StarlightTheme.primaryBlue
                : Colors.white.withOpacity(0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: StarlightTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bundle.bundleScope == 'institutional'
                          ? Colors.purple.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bundle.bundleScope,
                      style: TextStyle(
                        color: bundle.bundleScope == 'institutional'
                            ? Colors.purple
                            : Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected 
                            ? StarlightTheme.primaryBlue
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Name and Price
              Text(
                bundle.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rs. ${bundle.priceGold.toInt()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const Spacer(),
              
              // Features
              _buildFeatureRow('AI Credits', bundle.features.aiCredits ?? 0),
              _buildFeatureRow('Silver Bonus', bundle.features.grantSilver ?? 0),
              _buildFeatureRow('Validity', '${bundle.durationDays} Days'),
              
              if (bundle.isPopular)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          Text(
            value is String ? value : '+$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentBottomSheet(Map<String, dynamic> totals) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Rs. ${totals['pkr'].toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _isProcessingPayment ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: StarlightTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Pay Now'),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
