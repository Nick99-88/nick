import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'payment_service.dart';
import '../models/shop_models.dart';

class ShopIAPService {
  static final ShopIAPService _instance = ShopIAPService._();
  factory ShopIAPService() => _instance;
  ShopIAPService._();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  bool _ready = false;
  bool _busy = false;
  final Set<String> _consumed = {};

  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _sub;

  List<ProductDetails> get products => _products;
  bool get isReady => _ready;
  bool get isBusy => _busy;

  ProductDetails? find(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    if (_ready) return;
    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint('ShopIAP: Store unavailable');
      return;
    }
    _sub = _inAppPurchase.purchaseStream.listen(_onPurchase);
    _ready = true;
    debugPrint('ShopIAP: Initialized');
  }

  Future<List<ProductDetails>> fetch(List<String> ids) async {
    if (!_ready) await init();
    final res = await _inAppPurchase.queryProductDetails(ids.toSet());
    _products = res.productDetails;
    if (res.notFoundIDs.isNotEmpty) {
      debugPrint('ShopIAP: Missing products: ${res.notFoundIDs}');
    }
    return _products;
  }

  Future<bool> buy(ProductDetails product) async {
    if (_busy) return false;
    _busy = true;
    try {
      return await _inAppPurchase.buyConsumable(
        purchaseParam: GooglePlayPurchaseParam(
          productDetails: product,
          changeSubscriptionParam: null,
        ),
      );
    } catch (e) {
      debugPrint('ShopIAP: Buy error - $e');
      return false;
    } finally {
      _busy = false;
    }
  }

  void _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased) {
        final pid = p.purchaseID ?? '';
        if (_consumed.contains(pid)) continue;
        _consumed.add(pid);
        await _inAppPurchase.completePurchase(p);
        debugPrint('ShopIAP: Completed Google Play purchase for ${p.productID}');

        // Send purchase token to server for verification and wallet credit
        try {
          final verifier = ShopVerificationService();
          final verified = await verifier.verifyGooglePlayPurchase(
            p.productID,
            pid,
          );
          if (verified) {
            debugPrint('ShopIAP: Server verified purchase for ${p.productID}');
          } else {
            debugPrint('ShopIAP: Server rejected purchase for ${p.productID}');
          }
        } catch (e) {
          debugPrint('ShopIAP: Verification error - $e');
        }
      } else if (p.status == PurchaseStatus.error) {
        debugPrint('ShopIAP: Error ${p.error?.message}');
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _ready = false;
  }
}
