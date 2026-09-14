import 'package:flutter/material.dart';
import 'models/shop_models.dart';
import 'services/shop_service.dart';
import 'services/iap_service.dart';
import 'services/payment_service.dart';
import 'widgets/product_card.dart';
import 'widgets/wallet_display.dart';
import '../services/api_service.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  final ShopService _shopService = ShopService();
  final ShopIAPService _iapService = ShopIAPService();
  final ShopPaymentService _paymentService = ShopPaymentService();

  late TabController _tabController;

  List<ShopProduct> _products = [];
  ShopWallet? _wallet;
  bool _loading = true;

  ShopCategory _selectedCategory = ShopCategory.credits;

  final List<Map<String, dynamic>> _tabs = [
    {'label': 'CURRENCY', 'icon': Icons.monetization_on, 'category': ShopCategory.credits},
    {'label': 'SUBSCRIPTION', 'icon': Icons.stars, 'category': ShopCategory.subscription},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedCategory = _tabController.index == 0 ? ShopCategory.credits : ShopCategory.subscription;
        });
      }
    });
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      await _iapService.init();
    } catch (e) {
      debugPrint('ShopScreen: IAP init failed (non-blocking) - $e');
    }
    await Future.wait([
      _loadProducts(),
      _loadWallet(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProducts() async {
    // 1. Sync bundles from server to local SQLite cache
    try {
      await _shopService.syncBundles();
      debugPrint('ShopScreen: Server bundles synchronized to local cache.');
    } catch (e) {
      debugPrint('ShopScreen: Server sync failed, loading cached data: $e');
    }

    // 2. Fetch products from local SQLite cache (server-sourced)
    final serverProducts = await _shopService.getProducts();

    if (serverProducts.isNotEmpty) {
      // 3. Try to overlay Google Play IAP pricing where available
      try {
        final ids = serverProducts.map((p) => p.id).toList();
        final iapProducts = await _iapService.fetch(ids);

        if (iapProducts.isNotEmpty && mounted) {
          final iapMap = {for (final iap in iapProducts) iap.id: iap};
          setState(() {
            _products = serverProducts.map((sp) {
              final iap = iapMap[sp.id];
              if (iap != null) {
                return ShopProduct(
                  id: sp.id,
                  title: sp.title,
                  description: sp.description,
                  price: iap.rawPrice,
                  currency: iap.currencyCode ?? sp.currency,
                  icon: sp.icon,
                  color: sp.color,
                  category: sp.category,
                  isPopular: sp.isPopular,
                  specs: sp.specs,
                );
              }
              return sp;
            }).toList();
          });
          debugPrint('ShopScreen: Loaded ${_products.length} server bundles with IAP pricing overlay.');
          return;
        }
      } catch (e) {
        debugPrint('ShopScreen: IAP overlay unavailable, using server pricing: $e');
      }

      // 4. Fallback: use server products with server-side pricing
      if (mounted) {
        setState(() => _products = serverProducts);
        debugPrint('ShopScreen: Loaded ${_products.length} server bundles with server pricing.');
      }
    }
  }

  Future<void> _loadWallet() async {
    final wallet = await _shopService.getWallet();
    if (mounted) setState(() => _wallet = wallet);
  }

  List<ShopProduct> get _filtered {
    if (_selectedCategory == ShopCategory.credits) {
      return _products.where((p) => p.category == ShopCategory.credits).toList();
    } else {
      return _products.where((p) => p.category != ShopCategory.credits).toList();
    }
  }

  Future<void> _buy(ShopProduct product) async {
    debugPrint('ShopScreen: Initiating checkout for ${product.id}...');

    // Try Google Play IAP first
    final iapProduct = _iapService.find(product.id);
    if (iapProduct != null) {
      debugPrint('ShopScreen: Launching Google Play billing for ${iapProduct.id}...');
      try {
        final success = await _iapService.buy(iapProduct);
        if (!success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google Play purchase was cancelled or failed'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('ShopScreen: IAP buy error - $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
    } else {
      // IAP not available — fall back to sandbox server payment
      debugPrint('ShopScreen: IAP not found for ${product.id}, using sandbox payment.');
      try {
        await _paymentService.initiate(ShopPaymentRequest(
          amount: product.price,
          currency: product.currency,
          productId: product.id,
          paymentMethod: 'sandbox',
        ));
      } catch (e) {
        debugPrint('ShopScreen: Sandbox payment error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
    }

    await _loadWallet();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.title} purchased successfully!'),
          backgroundColor: product.color,
            behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _gift(ShopProduct product) async {
    final TextEditingController identifierCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15192E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.mark_email_unread_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('REQUEST A GIFT', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the prospective Gifter\'s details below (User ID, Email, or Name) to ask them to gift you "${product.title}".',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: identifierCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Gifter Identifier',
                  labelStyle: TextStyle(color: Colors.white38, fontSize: 11),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Identifier is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Send Request', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final identifier = identifierCtrl.text.trim();
    if (identifier.isEmpty) return;

    try {
      await ApiService.post('/mailbox/send', {
        'recipient_id': identifier,
        'title': 'GIFT REQUEST: ${product.title}',
        'body': 'Hi! I would love to have the "${product.title}" premium pack as a gift from you.',
        'attachments': ['gift_request:${product.id}'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gift request sent!'),
            backgroundColor: Colors.amber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('ShopScreen: Gift request error - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0E1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag, color: Colors.green, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starlight Shop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Premium Features & Credits', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _init,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : RefreshIndicator(
              onRefresh: _init,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ShopWalletDisplay(
                      wallet: _wallet ?? ShopWallet(
                        gold: 0, silver: 0, aiCredits: 0,
                        lastUpdated: DateTime.now(),
                      ),
                      onHistory: _showHistory,
                    ),
                    const SizedBox(height: 24),
                    _buildCategoryTabs(),
                    const SizedBox(height: 24),
                    if (_filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ..._buildProductGrid(_filtered),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF15192E),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final tab = entry.value;
          final active = tab['category'] == _selectedCategory;

          Color activeColor = tab['category'] == ShopCategory.credits ? Colors.amber : Colors.purpleAccent;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = tab['category'] as ShopCategory;
                });
                _tabController.animateTo(idx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(
                          colors: [activeColor, activeColor.withOpacity(0.7)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: active
                      ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: active ? Colors.white : Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildProductGrid(List<ShopProduct> items) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: ShopProductCard(
                  product: items[i],
                  onTap: () => _showDetail(items[i]),
                  onBuy: () => _buy(items[i]),
                  onGift: () => _gift(items[i]),
                ),
              ),
              if (i + 1 < items.length) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ShopProductCard(
                    product: items[i + 1],
                    onTap: () => _showDetail(items[i + 1]),
                    onBuy: () => _buy(items[i + 1]),
                    onGift: () => _gift(items[i + 1]),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('Nothing here yet', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _showDetail(ShopProduct product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111428),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: product.color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(product.icon, color: product.color, size: 40),
            ),
            const SizedBox(height: 12),
            Text(product.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(product.description, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.6))),
            if (product.specs.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...product.specs.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                    Text(e.value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () { Navigator.pop(context); _buy(product); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0072FF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  'Buy ${product.currency} ${product.price.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 400,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF111428),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: FutureBuilder<List<ShopTransaction>>(
          future: _shopService.getTransactions(),
          builder: (_, snap) {
            final txns = snap.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Transaction History', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (txns.isEmpty)
                  Expanded(child: Center(child: Text('No transactions', style: TextStyle(color: Colors.white.withOpacity(0.4)))))
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: txns.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.06)),
                      itemBuilder: (_, i) {
                        final t = txns[i];
                        Color typeColor;
                        IconData typeIcon;
                        switch (t.type) {
                          case 'purchase':
                          case 'gift_send':
                            typeColor = Colors.redAccent;
                            typeIcon = Icons.shopping_cart;
                            break;
                          case 'credit':
                          case 'bonus':
                          case 'daily_bonus':
                          case 'gift_receive':
                          case 'conversion_in':
                            typeColor = Colors.green;
                            typeIcon = Icons.add_circle;
                            break;
                          case 'conversion_out':
                            typeColor = Colors.orangeAccent;
                            typeIcon = Icons.remove_circle;
                            break;
                          default:
                            typeColor = Colors.grey;
                            typeIcon = Icons.help_outline;
                        }
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(typeIcon, color: typeColor, size: 18),
                          ),
                          title: Text(t.description, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Text('${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                          trailing: Text(
                            'G:${t.goldAmount} S:${t.silverAmount} AI:${t.aiCreditsAmount}',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
