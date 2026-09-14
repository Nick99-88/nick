import 'package:flutter/material.dart';
import '../../models/subscription_models.dart';
import '../../services/subscription/subscription_service.dart';
import '../../services/api_service.dart';
import '../../core/storage.dart';
import 'gold_transfer_receipt_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with TickerProviderStateMixin {
  final SubscriptionService _subscriptionService = SubscriptionService();
  UserWallet? _wallet;
  bool _isLoading = true;
  bool _exchanging = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _loadWalletData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletData() async {
    try {
      final wallet = await _subscriptionService.getUserWallet();
      if (mounted) setState(() { _wallet = wallet; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshWallet() async {
    setState(() => _isLoading = true);
    await _loadWalletData();
  }

  Future<void> _openGoldToSilverExchange() async {
    if (_wallet == null) return;
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Gold \u2192 Silver', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1 Gold Coin = 10 Silver Coins\nAvailable: ${_wallet!.goldCoins} Gold',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 24, fontWeight: FontWeight.bold),
                    prefixText: '\u{1F941} ',
                    prefixStyle: const TextStyle(fontSize: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setD(() {}),
                ),
                if (int.tryParse(ctrl.text) != null && int.parse(ctrl.text) > 0) ...[
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.05)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'You receive ${int.parse(ctrl.text) * 10} Silver Coins',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: const Text('Exchange Now', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    final amt = int.parse(ctrl.text.trim());
    setState(() => _exchanging = true);
    try {
      await ApiService.post('/subscription/convert/gold-to-silver', {'gold': amt});
      if (mounted) _showSnack('Exchanged $amt Gold \u2192 ${amt * 10} Silver!', Colors.green);
      _refreshWallet();
    } catch (e) {
      if (mounted) _showSnack('Exchange failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _exchanging = false);
    }
  }

  Future<void> _openSilverToAiExchange() async {
    if (_wallet == null) return;
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFA855F7), Color(0xFF7C3AED)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Silver \u2192 AI Credits', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.purpleAccent, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1 Silver Coin = 10 AI Credits\nAvailable: ${_wallet!.silverCoins} Silver',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 24, fontWeight: FontWeight.bold),
                    prefixText: '\u{26AA} ',
                    prefixStyle: const TextStyle(fontSize: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setD(() {}),
                ),
                if (int.tryParse(ctrl.text) != null && int.parse(ctrl.text) > 0) ...[
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.cyan.withOpacity(0.15), Colors.cyan.withOpacity(0.05)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'You receive ${int.parse(ctrl.text) * 10} AI Credits',
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFA855F7), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: const Text('Exchange Now', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    final amt = int.parse(ctrl.text.trim());
    setState(() => _exchanging = true);
    try {
      await ApiService.post('/subscription/convert/silver-to-ai', {'silver': amt});
      if (mounted) _showSnack('Exchanged $amt Silver \u2192 ${amt * 10} AI Credits!', Colors.green);
      _refreshWallet();
    } catch (e) {
      if (mounted) _showSnack('Exchange failed: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _exchanging = false);
    }
  }

  Future<void> _openTransferGoldDialog() async {
    if (_wallet == null) return;
    final publicIdCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool usePublicId = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Send Gold', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Available: ${_wallet!.goldCoins} Gold\nEnter Public ID or Phone (at least one).',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (usePublicId)
                  TextField(
                    controller: publicIdCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. A3B9K2X1',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                      labelText: 'Recipient Public ID',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                      prefixIcon: const Icon(Icons.badge_outlined, color: Colors.amber, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.swap_horiz, color: Colors.amber, size: 18),
                        onPressed: () => setD(() => usePublicId = false),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  )
                else
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. 03001234567',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                      labelText: 'Recipient Phone',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                      prefixIcon: const Icon(Icons.phone_outlined, color: Colors.amber, size: 18),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.swap_horiz, color: Colors.amber, size: 18),
                        onPressed: () => setD(() => usePublicId = true),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.04),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 24, fontWeight: FontWeight.bold),
                    prefixText: '\u{1F947} ',
                    prefixStyle: const TextStyle(fontSize: 20),
                    labelText: 'Gold Amount',
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setD(() {}),
                ),
                if (int.tryParse(amountCtrl.text) != null && int.parse(amountCtrl.text) > 0) ...[
                  const SizedBox(height: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.05)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward_rounded, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'You send ${int.parse(amountCtrl.text)} Gold',
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () {
                  final hasPublicId = publicIdCtrl.text.trim().isNotEmpty;
                  final hasPhone = phoneCtrl.text.trim().isNotEmpty;
                  if (!hasPublicId && !hasPhone) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter Public ID or Phone number'), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  if (amountCtrl.text.trim().isEmpty || int.tryParse(amountCtrl.text.trim()) == null || int.parse(amountCtrl.text.trim()) <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Enter a valid gold amount'), backgroundColor: Colors.redAccent),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Preview Transfer', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final amt = int.parse(amountCtrl.text.trim());
    setState(() => _exchanging = true);

    try {
      final service = SubscriptionService();
      final preview = await service.previewTransferGold(
        recipientPublicId: publicIdCtrl.text.trim(),
        recipientPhone: phoneCtrl.text.trim(),
        goldAmount: amt,
      );

      if (!mounted) return;
      setState(() => _exchanging = false);

      // Show confirmation dialog with recipient details
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_search_rounded, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Confirm Transfer', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRecipientRow('Name', preview['recipient_name'] ?? ''),
                _buildRecipientRow('Public ID', preview['recipient_public_id'] ?? ''),
                _buildRecipientRow('Role', (preview['recipient_role'] ?? '').toString().toUpperCase()),
                if ((preview['recipient_gender'] ?? '').toString().isNotEmpty)
                  _buildRecipientRow('Gender', preview['recipient_gender']),
                const Divider(color: Colors.white12, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Amount', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text('\u{1F947} $amt Gold', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your Balance After', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text('\u{1F947} ${(preview['sender_gold_balance'] ?? 0) - amt}', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm & Send', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        _refreshWallet();
        return;
      }

      // Execute transfer
      setState(() => _exchanging = true);
      final txResult = await service.confirmTransferGold(previewId: preview['preview_id']);
      if (mounted) {
        setState(() => _exchanging = false);
        _refreshWallet();
        _showTransferReceipt(txResult);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exchanging = false);
        _showSnack('Transfer failed: $e', Colors.red);
      }
    }
  }

  Widget _buildRecipientRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showTransferReceipt(Map<String, dynamic> tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoldTransferReceiptScreen(
          transactionId: tx['transaction_id'] ?? '',
          senderName: tx['sender_name'] ?? '',
          senderPublicId: tx['sender_public_id'] ?? '',
          recipientName: tx['recipient_name'] ?? '',
          recipientPublicId: tx['recipient_public_id'] ?? '',
          goldAmount: tx['gold_amount'] ?? 0,
          timestamp: tx['timestamp'] ?? '',
        ),
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E1A),
      appBar: AppBar(
        title: const Text('My Ledger Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _exchanging ? null : _refreshWallet,
            icon: _exchanging
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                : const Icon(Icons.refresh, color: Colors.white54),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _wallet != null
              ? RefreshIndicator(
                  onRefresh: _refreshWallet,
                  color: Colors.amber,
                  backgroundColor: const Color(0xFF1A1A2E),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildBalanceCards(),
                        _buildConversionStation(),
                        _buildRecentTransactions(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      const Text('No wallet ledger found', style: TextStyle(color: Colors.white38, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('Start earning to see your balance', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A3E), Color(0xFF0B0E1A)],
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFB8860B)],
                    stops: [0.3, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 24, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.black87, size: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Total Net Worth',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, _) {
              return Text(
                '${_wallet!.goldCoins + _wallet!.silverCoins + _wallet!.aiCredits}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Total Coins & Credits',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCards() {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: _buildBalanceCard('Gold', _wallet!.goldCoins, const Color(0xFFFFD700), const Color(0xFFB8860B), Icons.hexagon_rounded, 'Top-tier currency')),
            const SizedBox(width: 10),
            Expanded(child: _buildBalanceCard('Silver', _wallet!.silverCoins, const Color(0xFFC0C0C0), const Color(0xFF808080), Icons.circle_rounded, 'Standard currency')),
            const SizedBox(width: 10),
            Expanded(child: _buildBalanceCard('AI', _wallet!.aiCredits, const Color(0xFFA855F7), const Color(0xFF7C3AED), Icons.auto_awesome_rounded, 'AI service credits')),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String label, int amount, Color primary, Color secondary, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withOpacity(0.12),
            primary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: primary.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primary, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            '$amount',
            style: TextStyle(
              color: primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: primary.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: primary.withOpacity(0.4), fontSize: 7, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionStation() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('EXCHANGE', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
              const SizedBox(width: 8),
              Text('Convert between currencies', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildExchangeCard(
                'Gold \u2192 Silver',
                '1 Gold = 10 Silver',
                const Color(0xFFFFD700),
                const Color(0xFFFFA500),
                Icons.swap_horiz_rounded,
                _openGoldToSilverExchange,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildExchangeCard(
                'Silver \u2192 AI',
                '1 Silver = 10 AI Credits',
                const Color(0xFFA855F7),
                const Color(0xFF7C3AED),
                Icons.auto_awesome_rounded,
                _openSilverToAiExchange,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildExchangeCard(
                'Send Gold',
                'P2P Transfer to others',
                const Color(0xFFFFD700),
                const Color(0xFFE6A800),
                Icons.send_rounded,
                _openTransferGoldDialog,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeCard(String title, String rate, Color c1, Color c2, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c1.withOpacity(0.08), c2.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c1.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c1, c2]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: c1.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(rate, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (_wallet!.transactions == null || _wallet!.transactions!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('LEDGER LOGS', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                  const SizedBox(width: 8),
                  Text('Recent activity', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
                ],
              ),
              TextButton(
                onPressed: _showTransactionHistory,
                child: const Text('View All \u2192', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._wallet!.transactions!.take(5).map((tx) => _buildTransactionCard(tx)),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(WalletTransaction tx) {
    final (typeColor, typeIcon, label) = _transactionStyle(tx.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(typeIcon, color: typeColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (tx.goldAmount != 0)
                _amountChip('\u{1F947}', tx.goldAmount, Colors.amber),
              if (tx.silverAmount != 0)
                Padding(
                  padding: EdgeInsets.only(top: tx.goldAmount != 0 ? 4 : 0),
                  child: _amountChip('\u{26AA}', tx.silverAmount, Colors.grey),
                ),
              if (tx.aiCreditsAmount != 0)
                Padding(
                  padding: EdgeInsets.only(top: (tx.goldAmount != 0 || tx.silverAmount != 0) ? 4 : 0),
                  child: _amountChip('\u{2728}', tx.aiCreditsAmount, Colors.cyan),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountChip(String emoji, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$emoji ${amount > 0 ? '+' : ''}$amount',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  (Color, IconData, String) _transactionStyle(String type) {
    switch (type) {
      case 'purchase':
        return (Colors.redAccent, Icons.shopping_cart_rounded, 'PURCHASE');
      case 'credit':
      case 'conversion_in':
        return (Colors.green, Icons.add_circle_rounded, 'CREDIT');
      case 'conversion_out':
        return (Colors.orangeAccent, Icons.remove_circle_rounded, 'CONVERSION OUT');
      case 'bonus':
      case 'daily_bonus':
        return (Colors.amber, Icons.card_giftcard_rounded, 'BONUS');
      case 'gold_transfer_send':
        return (Colors.redAccent, Icons.arrow_upward_rounded, 'SENT GOLD');
      case 'gold_transfer_receive':
        return (Colors.green, Icons.arrow_downward_rounded, 'RECEIVED GOLD');
      default:
        return (Colors.grey, Icons.help_outline_rounded, type.toUpperCase());
    }
  }

  void _showTransactionHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Complete History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('All wallet transactions', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              const SizedBox(height: 16),
              Flexible(
                child: _wallet?.transactions != null
                    ? ListView.separated(
                        shrinkWrap: true,
                        itemCount: _wallet!.transactions!.length,
                        separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.03), height: 8),
                        itemBuilder: (context, index) {
                          final tx = _wallet!.transactions![index];
                          final (color, icon, _) = _transactionStyle(tx.type);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(icon, color: color, size: 14),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(tx.description, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 10, color: Colors.white38),
                                      ),
                                    ],
                                  ),
                                ),
                                if (tx.goldAmount != 0)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text('${tx.goldAmount}G', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                  ),
                                if (tx.silverAmount != 0)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text('${tx.silverAmount}S', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                  ),
                                if (tx.aiCreditsAmount != 0)
                                  Text('${tx.aiCreditsAmount}A', style: const TextStyle(color: Colors.cyan, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(child: Text('No transactions', style: TextStyle(color: Colors.white38))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
