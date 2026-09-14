import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/subscription_models.dart';

class CoinDisplayWidget extends StatelessWidget {
  final UserWallet wallet;

  const CoinDisplayWidget({
    super.key,
    required this.wallet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCoinItem('Gold', wallet.goldCoins, Colors.amber),
          const SizedBox(width: 8),
          _buildCoinItem('Silver', wallet.silverCoins, Colors.grey),
          const SizedBox(width: 8),
          _buildCoinItem('AI', wallet.aiCredits, StarlightTheme.primaryBlue),
        ],
      ),
    );
  }

  Widget _buildCoinItem(String label, int amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getIconForLabel(label),
          color: color,
          size: 16,
        ),
        const SizedBox(width: 4),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              amount.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Gold':
        return Icons.monetization_on;
      case 'Silver':
        return Icons.currency_exchange;
      case 'AI':
        return Icons.smart_toy;
      default:
        return Icons.help_outline;
    }
  }
}

class DetailedCoinDisplay extends StatelessWidget {
  final UserWallet wallet;
  final VoidCallback? onHistoryTap;

  const DetailedCoinDisplay({
    super.key,
    required this.wallet,
    this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Wallet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onHistoryTap != null)
                TextButton(
                  onPressed: onHistoryTap,
                  child: const Text(
                    'History',
                    style: TextStyle(
                      color: StarlightTheme.primaryBlue,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDetailedCoinItem('Gold', wallet.goldCoins, Colors.amber, 'Premium currency for purchases')),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailedCoinItem('Silver', wallet.silverCoins, Colors.grey, 'Standard currency for features')),
              const SizedBox(width: 12),
              Expanded(child: _buildDetailedCoinItem('AI Credits', wallet.aiCredits, StarlightTheme.primaryBlue, 'AI-powered features')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedCoinItem(String label, int amount, Color color, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            _getIconForLabel(label),
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            amount.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Gold':
        return Icons.monetization_on;
      case 'Silver':
        return Icons.currency_exchange;
      case 'AI Credits':
        return Icons.smart_toy;
      default:
        return Icons.help_outline;
    }
  }
}
