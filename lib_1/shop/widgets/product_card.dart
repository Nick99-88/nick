import 'package:flutter/material.dart';
import '../models/shop_models.dart';

class ShopProductCard extends StatelessWidget {
  final ShopProduct product;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final VoidCallback onGift;

  const ShopProductCard({
    super.key,
    required this.product,
    this.selected = false,
    required this.onTap,
    required this.onBuy,
    required this.onGift,
  });

  @override
  Widget build(BuildContext context) {
    // Determine card colors based on category/type
    final isCurrency = product.category == ShopCategory.credits;
    final accentColor = isCurrency ? Colors.amber : Colors.purpleAccent;

    // Map illustrative game-like icons for premium gaming look matching mockup
    IconData displayIcon = product.icon;
    if (product.id.contains('1000')) {
      displayIcon = Icons.rocket_launch; // Star Boost x5 Look
    } else if (product.id.contains('5000')) {
      displayIcon = Icons.bolt; // Energy Recharge Look
    } else if (product.id.contains('10000')) {
      displayIcon = Icons.card_giftcard; // Mystic Chest Look
    } else if (product.id.contains('basic')) {
      displayIcon = Icons.stars; // Basic membership Look
    } else if (product.id.contains('pro')) {
      displayIcon = Icons.diamond; // Pro membership Look
    } else if (product.id.contains('enterprise')) {
      displayIcon = Icons.shield; // Enterprise membership Look
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          color: const Color(0xFF111428), // Dark glowing background
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? accentColor : accentColor.withOpacity(0.12),
            width: selected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(selected ? 0.25 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Product Glowing Illustrative Icon
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    displayIcon,
                    color: accentColor,
                    size: 32,
                  ),
                  if (product.isPopular)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Product Text Information
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Text(
                    product.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCurrency ? 'IN-APP CURRENCY' : 'PREMIUM MEMBERSHIP',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Product Price Card Tag (e.g. 500 Gold Star)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${product.price.toInt()}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star,
                        color: Colors.amberAccent,
                        size: 13,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons (Buy & Gift) in Row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Row(
                children: [
                  // Buy Button
                  Expanded(
                    flex: 5,
                    child: GestureDetector(
                      onTap: onBuy,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)], // Mockup blue capsule gradient
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0072FF).withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'BUY NOW',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Gift Button
                  Expanded(
                    flex: 4,
                    child: GestureDetector(
                      onTap: onGift,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF107A3), Color(0xFF7B2CBF)], // Magenta/Purple gradient
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2CBF).withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'GIFT',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
