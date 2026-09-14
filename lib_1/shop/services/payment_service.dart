import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../models/shop_models.dart';

class ShopPaymentService {
  static final ShopPaymentService _instance = ShopPaymentService._();
  factory ShopPaymentService() => _instance;
  ShopPaymentService._();

  Future<String?> _token() async => await StarlightStorage.getUserToken();

  Future<ShopPaymentResponse> initiate(ShopPaymentRequest request) async {
    final token = await _token();
    if (token == null) throw Exception('Not authenticated');

    final res = await http.post(
      Uri.parse('${StarlightConstants.apiBaseUrl}/shop/payment/initiate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(request.toJson()),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return ShopPaymentResponse(
        paymentId: data['payment_id'] ?? '',
        checkoutUrl: data['checkout_url'],
        status: data['status'] ?? 'completed',
      );
    }
    throw Exception('Payment failed: HTTP ${res.statusCode}');
  }
}

class ShopVerificationService {
  static final ShopVerificationService _instance = ShopVerificationService._();
  factory ShopVerificationService() => _instance;
  ShopVerificationService._();

  Future<String?> _token() async => await StarlightStorage.getUserToken();

  Future<bool> verifyGooglePlayPurchase(String productId, String purchaseToken) async {
    try {
      final token = await _token();
      if (token == null) throw Exception('Not authenticated');

      final res = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/shop/iap/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'product_id': productId,
          'purchase_token': purchaseToken,
        }),
      );

      if (res.statusCode == 200) {
        debugPrint('ShopVerification: Purchase verified for $productId');
        return true;
      }
      debugPrint('ShopVerification: Server rejected purchase (${res.statusCode})');
      return false;
    } catch (e) {
      debugPrint('ShopVerification: Error - $e');
      return false;
    }
  }
}
