import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/subscription/subscription_service.dart';
import '../services/library_service.dart';

class LibraryPurchaseDialog extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int price;
  final String monetization; // 'sell', 'rent', 'user_decision'

  const LibraryPurchaseDialog({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.price,
    required this.monetization,
  });

  @override
  State<LibraryPurchaseDialog> createState() => _LibraryPurchaseDialogState();
}

class _LibraryPurchaseDialogState extends State<LibraryPurchaseDialog> {
  int? _balance;
  bool _loading = true;
  bool _processing = false;

  final SubscriptionService _subService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final wallet = await _subService.getUserWallet();
      if (mounted) setState(() { _balance = wallet.goldCoins; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _purchase(String type) async {
    setState(() => _processing = true);
    try {
      await LibraryService.purchaseBook(widget.bookId, type);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'buy' ? 'Purchased successfully!' : 'Rented successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canBuy = widget.monetization == 'sell' || widget.monetization == 'user_decision';
    final canRent = widget.monetization == 'rent' || widget.monetization == 'user_decision';
    final insufficient = _balance != null && _balance! < widget.price;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 10),
          const Text("Unlock Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.bookTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Price: ", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                Text("${widget.price} Gold", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text("Your Balance: ", style: TextStyle(fontSize: 13, color: Colors.grey)),
                _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(
                        children: [
                          const Icon(Icons.monetization_on, size: 16, color: Colors.amber),
                          Text("$_balance Gold", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: insufficient ? Colors.red : Colors.green)),
                        ],
                      ),
              ],
            ),
            if (insufficient && !_loading) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, size: 16, color: Colors.red),
                    SizedBox(width: 6),
                    Expanded(child: Text("Insufficient gold. Earn more by completing daily tasks.", style: TextStyle(fontSize: 11, color: Colors.red))),
                  ],
                ),
              ),
            ],
            if (widget.monetization == 'user_decision') ...[
              const SizedBox(height: 8),
              const Text("Choose your access:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _processing ? null : () => Navigator.pop(context), child: const Text("Cancel")),
        if (canBuy)
          _processing
              ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : ElevatedButton.icon(
                  onPressed: insufficient ? null : () => _purchase('buy'),
                  icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                  label: Text(canRent ? "Buy (${widget.price} Gold)" : "Purchase (${widget.price} Gold)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
        if (canRent)
          _processing
              ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : TextButton.icon(
                  onPressed: insufficient ? null : () => _purchase('rent'),
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text("Rent (${widget.price} Gold / 30 days)"),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
      ],
    );
  }
}
