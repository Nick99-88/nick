import 'package:flutter/material.dart';

enum ShopCategory { credits, subscription, feature, tool }

class ShopProduct {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final IconData icon;
  final Color color;
  final ShopCategory category;
  final bool isPopular;
  final Map<String, String> specs;

  const ShopProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.currency = 'PKR',
    required this.icon,
    required this.color,
    required this.category,
    this.isPopular = false,
    this.specs = const {},
  });
}

class ShopWallet {
  final int gold;
  final int silver;
  final int aiCredits;
  final DateTime lastUpdated;

  const ShopWallet({
    required this.gold,
    required this.silver,
    required this.aiCredits,
    required this.lastUpdated,
  });
}

class ShopTransaction {
  final String id;
  final String type;
  final String description;
  final int goldAmount;
  final int silverAmount;
  final int aiCreditsAmount;
  final DateTime createdAt;

  const ShopTransaction({
    required this.id,
    required this.type,
    required this.description,
    required this.goldAmount,
    required this.silverAmount,
    required this.aiCreditsAmount,
    required this.createdAt,
  });
}

class ShopPaymentRequest {
  final double amount;
  final String currency;
  final String productId;
  final String? paymentMethod;
  final String? recipientId;

  const ShopPaymentRequest({
    required this.amount,
    required this.currency,
    required this.productId,
    this.paymentMethod,
    this.recipientId,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency': currency,
    'product_id': productId,
    'payment_method': paymentMethod,
    if (recipientId != null) 'recipient_id': recipientId,
  };
}

class ShopPaymentResponse {
  final String paymentId;
  final String? checkoutUrl;
  final String status;

  const ShopPaymentResponse({
    required this.paymentId,
    this.checkoutUrl,
    required this.status,
  });
}

class ShopOrder {
  final String orderId;
  final String productId;
  final double amount;
  final String currency;
  final String status;
  final DateTime createdAt;

  const ShopOrder({
    required this.orderId,
    required this.productId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });
}
