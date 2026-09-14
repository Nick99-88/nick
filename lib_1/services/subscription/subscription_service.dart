import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../services/signed_api_service.dart';
import '../../models/subscription_models.dart';

class SubscriptionService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/subscription";

  /// 🏛️ Fetch all available subscription bundles
  Future<List<SubscriptionBundle>> getBundles() async {
    try {
      final data = await SignedApiService.get("$_baseUrl/bundles");
      final bundles = (data['bundles'] as List)
          .map((bundle) => SubscriptionBundle.fromJson(bundle))
          .toList();
      return bundles;
    } catch (e) {
      print("Error fetching bundles: $e");
      return _getMockBundles();
    }
  }

  /// 🏛️ Get user's current wallet balance
  Future<UserWallet> getUserWallet() async {
    try {
      final data = await SignedApiService.get("$_baseUrl/wallet");
      return UserWallet.fromJson(data);
    } catch (e) {
      print("Error fetching wallet: $e");
      return _getMockWallet();
    }
  }

  /// 🏛️ Fetch wallet summary + active subscriptions and cache locally
  Future<Map<String, dynamic>> fetchAndCacheWalletSummary() async {
    try {
      final data = await SignedApiService.get("$_baseUrl/wallet/summary");
      await StarlightStorage.cacheWalletData(
        gold: data['gold_coins'] ?? 0,
        silver: data['silver_coins'] ?? 0,
        aiCredits: data['ai_credits'] ?? 0,
        subscriptions: data['active_subscriptions'] != null
            ? List<Map<String, dynamic>>.from(data['active_subscriptions'])
            : null,
      );
      return data;
    } catch (e) {
      print("Error fetching wallet summary: $e");
      return await StarlightStorage.getCachedWallet();
    }
  }

  /// 🏛️ Initiate payment with Google Pay/SafePay
  Future<PaymentResponse> initiatePayment(PaymentRequest request) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/initiate-payment",
        request.toJson(),
      );
      return PaymentResponse.fromJson(data);
    } catch (e) {
      print("Error initiating payment: $e");
      return PaymentResponse(
        paymentId: "mock_payment_${DateTime.now().millisecondsSinceEpoch}",
        checkoutUrl: "https://sandbox.api.getsafepay.com/checkout/render?beacon=mock_tracker&env=sandbox",
        trackerId: "mock_tracker",
        status: "pending",
        userEmail: "user@example.com",
      );
    }
  }

  /// 🏛️ Get bonus for visiting site
  Future<Map<String, int>> getDailyBonus() async {
    try {
      final data = await SignedApiService.post("$_baseUrl/daily-bonus", {});
      return {
        'gold': data['gold_bonus'] ?? 5,
        'silver': data['silver_bonus'] ?? 50,
        'ai_credits': data['ai_credits_bonus'] ?? 2,
      };
    } catch (e) {
      print("Error claiming bonus: $e");
      return {
        'gold': 5,
        'silver': 50,
        'ai_credits': 2,
      };
    }
  }

  /// 🏛️ Check if user can claim daily bonus
  Future<bool> canClaimDailyBonus() async {
    try {
      final data = await SignedApiService.get("$_baseUrl/daily-bonus-status");
      return data['can_claim'] ?? false;
    } catch (e) {
      print("Error checking bonus status: $e");
      return false;
    }
  }

  /// 🏛️ P2P Gold Transfer — Step 1: Preview
  Future<Map<String, dynamic>> previewTransferGold({
    required String recipientPublicId,
    required String recipientPhone,
    required int goldAmount,
  }) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/transfer/gold/preview",
        {
          "recipient_public_id": recipientPublicId,
          "recipient_phone": recipientPhone,
          "gold_amount": goldAmount,
        },
      );
      return data;
    } catch (e) {
      print("Error previewing transfer: $e");
      rethrow;
    }
  }

  /// 🏛️ P2P Gold Transfer — Step 2: Confirm
  Future<Map<String, dynamic>> confirmTransferGold({
    required String previewId,
  }) async {
    try {
      final data = await SignedApiService.post(
        "$_baseUrl/transfer/gold/confirm",
        {"preview_id": previewId},
      );
      return data;
    } catch (e) {
      print("Error confirming transfer: $e");
      rethrow;
    }
  }

  /// 🏛️ Get wallet transaction history
  Future<List<WalletTransaction>> getTransactionHistory() async {
    try {
      final data = await SignedApiService.get("$_baseUrl/wallet/transactions");
      final transactions = (data['transactions'] as List)
          .map((t) => WalletTransaction.fromJson(t))
          .toList();
      return transactions;
    } catch (e) {
      print("Error fetching transactions: $e");
      return [];
    }
  }

  /// 🏛️ Mock bundles for development
  List<SubscriptionBundle> _getMockBundles() {
    return [
      SubscriptionBundle(
        id: 'credit_pack_small',
        name: 'Starter Pack',
        priceGold: 100,
        bundleScope: 'personal',
        durationDays: 1,
        features: BundleFeatures(aiCredits: 50, grantSilver: 300),
        category: 'credits',
      ),
      SubscriptionBundle(
        id: 'credit_pack_medium',
        name: 'Pro Pack',
        priceGold: 500,
        bundleScope: 'personal',
        durationDays: 1,
        features: BundleFeatures(aiCredits: 300, grantSilver: 1500),
        category: 'credits',
        isPopular: true,
      ),
      SubscriptionBundle(
        id: 'credit_pack_large',
        name: 'Enterprise Pack',
        priceGold: 1000,
        bundleScope: 'personal',
        durationDays: 1,
        features: BundleFeatures(aiCredits: 750, grantSilver: 3000),
        category: 'credits',
      ),
      SubscriptionBundle(
        id: 'sub_basic_monthly',
        name: 'Basic Monthly',
        priceGold: 299,
        bundleScope: 'personal',
        durationDays: 30,
        features: BundleFeatures(aiCredits: 100, grantSilver: 500, premiumSupport: true),
        category: 'subscriptions',
      ),
      SubscriptionBundle(
        id: 'sub_pro_monthly',
        name: 'Pro Monthly',
        priceGold: 799,
        bundleScope: 'personal',
        durationDays: 30,
        features: BundleFeatures(aiCredits: 500, grantSilver: 2000, premiumSupport: true, advancedAnalytics: true),
        category: 'subscriptions',
        isPopular: true,
      ),
      SubscriptionBundle(
        id: 'sub_enterprise_monthly',
        name: 'Enterprise Monthly',
        priceGold: 1499,
        bundleScope: 'institutional',
        durationDays: 30,
        features: BundleFeatures(aiCredits: 1500, grantSilver: 5000, premiumSupport: true, advancedAnalytics: true, unlimitedStorage: true, maxUsers: 50),
        category: 'subscriptions',
      ),
      SubscriptionBundle(
        id: 'sub_institutional_yearly',
        name: 'Institutional Yearly',
        priceGold: 14999,
        bundleScope: 'institutional',
        durationDays: 365,
        features: BundleFeatures(aiCredits: 20000, grantSilver: 75000, premiumSupport: true, advancedAnalytics: true, unlimitedStorage: true, maxUsers: 200),
        category: 'subscriptions',
      ),
    ];
  }

  /// 🏛️ Mock wallet for development
  UserWallet _getMockWallet() {
    return UserWallet(
      goldCoins: 150,
      silverCoins: 750,
      aiCredits: 25,
      lastUpdated: DateTime.now(),
      transactions: [
        WalletTransaction(
          id: 'tx_001',
          type: 'purchase',
          description: 'Pro Pack Purchase',
          goldAmount: -500,
          silverAmount: 1500,
          aiCreditsAmount: 300,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          bundleId: 'credit_pack_medium',
          paymentMethod: 'google_pay',
        ),
        WalletTransaction(
          id: 'tx_002',
          type: 'bonus',
          description: 'Daily Visit Bonus',
          goldAmount: 5,
          silverAmount: 50,
          aiCreditsAmount: 2,
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    );
  }
}
