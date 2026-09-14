import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../models/subscription_models.dart';
import '../subscription/subscription_service.dart';

class GooglePayService {
  static const String _sandboxUrl = 'https://sandbox.api.getsafepay.com';
  static const String _productionUrl = 'https://api.getsafepay.com';
  
  final SubscriptionService _subscriptionService = SubscriptionService();

  /// 🏛️ Initialize Google Pay payment
  Future<Map<String, dynamic>?> initializePayment({
    required double amount,
    required String currency,
    required String orderId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/payment/initiate-google-pay'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
          'order_id': orderId,
          'callback_url': '${StarlightConstants.apiBaseUrl}/payment/callback',
          'metadata': metadata ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'payment_id': data['payment_id'],
          'checkout_url': data['checkout_url'],
          'tracker': data['tracker'],
          'expires_at': data['expires_at'],
        };
      } else {
        throw Exception('Failed to initialize payment');
      }
    } catch (e) {
      print('Error initializing Google Pay: $e');
      return null;
    }
  }

  /// 🏛️ Process payment result after callback
  Future<bool> processPaymentCallback({
    required String paymentId,
    required String tracker,
    required Map<String, dynamic> result,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/payment/callback'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'payment_id': paymentId,
          'tracker': tracker,
          'result': result,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error processing payment callback: $e');
      return false;
    }
  }

  /// 🏛️ Check payment status
  Future<Map<String, dynamic>?> getPaymentStatus(String paymentId) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/payment/status/$paymentId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error checking payment status: $e');
      return null;
    }
  }

  /// 🏛️ Launch SafePay checkout (alternative to Google Pay)
  Future<String?> launchSafePayCheckout({
    required double amount,
    required List<String> bundleIds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final paymentRequest = PaymentRequest(
        amount: amount,
        currency: 'PKR',
        bundleIds: bundleIds,
        paymentMethod: 'safepay',
        metadata: metadata,
      );

      final paymentResponse = await _subscriptionService.initiatePayment(paymentRequest);
      
      if (paymentResponse.checkoutUrl != null) {
        return paymentResponse.checkoutUrl;
      }
      
      return null;
    } catch (e) {
      print('Error launching SafePay checkout: $e');
      return null;
    }
  }

  /// 🏛️ Validate payment signature (for security)
  bool validatePaymentSignature(Map<String, dynamic> paymentData, String signature) {
    try {
      // In a real implementation, you would verify the signature
      // using the merchant's secret key
      final dataString = jsonEncode(paymentData);
      // This is a placeholder for actual signature verification
      return signature.isNotEmpty && dataString.isNotEmpty;
    } catch (e) {
      print('Error validating payment signature: $e');
      return false;
    }
  }

  /// 🏛️ Get supported payment methods
  Future<List<String>> getSupportedPaymentMethods() async {
    try {
      final response = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/payment/methods'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['methods'] ?? ['google_pay', 'safepay', 'credit_card']);
      }
      
      return ['google_pay', 'safepay', 'credit_card'];
    } catch (e) {
      print('Error getting payment methods: $e');
      return ['google_pay', 'safepay', 'credit_card'];
    }
  }

  /// 🏛️ Create payment order
  Future<Map<String, dynamic>?> createOrder({
    required double amount,
    required List<String> bundleIds,
    required String currency,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/payment/create-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'order_id': orderId,
          'amount': amount,
          'currency': currency,
          'bundle_ids': bundleIds,
          'metadata': metadata ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'order_id': orderId,
          'amount': amount,
          'currency': currency,
          'status': 'created',
          'expires_at': data['expires_at'],
        };
      }
      
      return null;
    } catch (e) {
      print('Error creating order: $e');
      return null;
    }
  }

  /// 🏛️ Handle payment result processing
  Future<bool> handlePaymentResult({
    required String orderId,
    required String paymentId,
    required bool success,
    Map<String, dynamic>? resultData,
  }) async {
    try {
      final token = await StarlightStorage.getUserToken();
      if (token == null) {
        throw Exception('User not authenticated');
      }

      final response = await http.post(
        Uri.parse('${StarlightConstants.apiBaseUrl}/payment/result'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'order_id': orderId,
          'payment_id': paymentId,
          'success': success,
          'result_data': resultData ?? {},
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error handling payment result: $e');
      return false;
    }
  }
}
