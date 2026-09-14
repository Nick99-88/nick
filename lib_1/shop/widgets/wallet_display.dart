import 'package:flutter/material.dart';
import '../models/shop_models.dart';

class ShopWalletDisplay extends StatelessWidget {
  final ShopWallet wallet;
  final VoidCallback? onHistory;

  const ShopWalletDisplay({super.key, required this.wallet, this.onHistory});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Wallet', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: onHistory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('History', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _coin(Icons.monetization_on, 'Gold', wallet.gold.toString(), Colors.amber),
              _coin(Icons.circle, 'Silver', wallet.silver.toString(), Colors.grey.shade300),
              _coin(Icons.auto_awesome, 'AI', wallet.aiCredits.toString(), Colors.cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coin(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
      ],
    );
  }
}
