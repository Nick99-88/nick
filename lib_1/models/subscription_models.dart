class SubscriptionBundle {
  final String id;
  final String name;
  final double priceGold;
  final String bundleScope; // personal or institutional
  final int durationDays;
  final BundleFeatures features;
  final String? description;
  final bool isPopular;
  final String? category;

  SubscriptionBundle({
    required this.id,
    required this.name,
    required this.priceGold,
    required this.bundleScope,
    required this.durationDays,
    required this.features,
    this.description,
    this.isPopular = false,
    this.category,
  });

  factory SubscriptionBundle.fromJson(Map<String, dynamic> json) {
    return SubscriptionBundle(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      priceGold: (json['price_gold'] ?? 0).toDouble(),
      bundleScope: json['bundle_scope'] ?? 'personal',
      durationDays: json['duration_days'] ?? 0,
      features: BundleFeatures.fromJson(json['features'] ?? {}),
      description: json['description'],
      isPopular: json['is_popular'] ?? false,
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price_gold': priceGold,
      'bundle_scope': bundleScope,
      'duration_days': durationDays,
      'features': features.toJson(),
      'description': description,
      'is_popular': isPopular,
      'category': category,
    };
  }
}

class BundleFeatures {
  final int? aiCredits;
  final int? grantSilver;
  final int? grantGold;
  final bool? premiumSupport;
  final bool? advancedAnalytics;
  final bool? unlimitedStorage;
  final int? maxUsers;
  final List<String>? customFeatures;

  BundleFeatures({
    this.aiCredits,
    this.grantSilver,
    this.grantGold,
    this.premiumSupport,
    this.advancedAnalytics,
    this.unlimitedStorage,
    this.maxUsers,
    this.customFeatures,
  });

  factory BundleFeatures.fromJson(Map<String, dynamic> json) {
    return BundleFeatures(
      aiCredits: json['ai_credits'],
      grantSilver: json['grant_silver'],
      grantGold: json['grant_gold'],
      premiumSupport: json['premium_support'],
      advancedAnalytics: json['advanced_analytics'],
      unlimitedStorage: json['unlimited_storage'],
      maxUsers: json['max_users'],
      customFeatures: json['custom_features'] != null 
          ? List<String>.from(json['custom_features'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ai_credits': aiCredits,
      'grant_silver': grantSilver,
      'grant_gold': grantGold,
      'premium_support': premiumSupport,
      'advanced_analytics': advancedAnalytics,
      'unlimited_storage': unlimitedStorage,
      'max_users': maxUsers,
      'custom_features': customFeatures,
    };
  }
}

class UserWallet {
  final int goldCoins;
  final int silverCoins;
  final int aiCredits;
  final DateTime? lastUpdated;
  final List<WalletTransaction>? transactions;

  UserWallet({
    required this.goldCoins,
    required this.silverCoins,
    required this.aiCredits,
    this.lastUpdated,
    this.transactions,
  });

  factory UserWallet.fromJson(Map<String, dynamic> json) {
    return UserWallet(
      goldCoins: json['gold_coins'] ?? 0,
      silverCoins: json['silver_coins'] ?? 0,
      aiCredits: json['ai_credits'] ?? 0,
      lastUpdated: json['last_updated'] != null 
          ? DateTime.parse(json['last_updated'])
          : null,
      transactions: json['transactions'] != null
          ? (json['transactions'] as List)
              .map((t) => WalletTransaction.fromJson(t))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gold_coins': goldCoins,
      'silver_coins': silverCoins,
      'ai_credits': aiCredits,
      'last_updated': lastUpdated?.toIso8601String(),
      'transactions': transactions?.map((t) => t.toJson()).toList(),
    };
  }
}

class WalletTransaction {
  final String id;
  final String type; // purchase, credit, bonus
  final String description;
  final int goldAmount;
  final int silverAmount;
  final int aiCreditsAmount;
  final DateTime createdAt;
  final String? bundleId;
  final String? paymentMethod;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.description,
    required this.goldAmount,
    required this.silverAmount,
    required this.aiCreditsAmount,
    required this.createdAt,
    this.bundleId,
    this.paymentMethod,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      goldAmount: json['gold_amount'] ?? 0,
      silverAmount: json['silver_amount'] ?? 0,
      aiCreditsAmount: json['ai_credits_amount'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      bundleId: json['bundle_id'],
      paymentMethod: json['payment_method'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'gold_amount': goldAmount,
      'silver_amount': silverAmount,
      'ai_credits_amount': aiCreditsAmount,
      'created_at': createdAt.toIso8601String(),
      'bundle_id': bundleId,
      'payment_method': paymentMethod,
    };
  }
}

class PaymentRequest {
  final double amount;
  final String currency;
  final List<String> bundleIds;
  final String? paymentMethod;
  final Map<String, dynamic>? metadata;

  PaymentRequest({
    required this.amount,
    required this.currency,
    required this.bundleIds,
    this.paymentMethod,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'bundle_ids': bundleIds,
      'payment_method': paymentMethod,
      'metadata': metadata,
    };
  }
}

class PaymentResponse {
  final String paymentId;
  final String? checkoutUrl;
  final String? trackerId;
  final String status;
  final String? userEmail;

  PaymentResponse({
    required this.paymentId,
    this.checkoutUrl,
    this.trackerId,
    required this.status,
    this.userEmail,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      paymentId: json['payment_id'] ?? '',
      checkoutUrl: json['checkout_url'],
      trackerId: json['tracker_id'],
      status: json['status'] ?? '',
      userEmail: json['user_email'],
    );
  }
}
