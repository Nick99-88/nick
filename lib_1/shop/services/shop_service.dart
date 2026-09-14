import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../core/constants.dart';
import '../../core/storage.dart';
import '../../core/database_helper.dart';
import '../models/shop_models.dart';

class ShopService {
  static final ShopService _instance = ShopService._();
  factory ShopService() => ShopService._();
  ShopService._();

  Future<String?> _token() async => await StarlightStorage.getUserToken();

  Future<void> syncBundles() async {
    try {
      final token = await _token();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/shop/bundles/ids'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        debugPrint('ShopService: syncBundles failed with status: ${res.statusCode}');
        return;
      }

      final data = jsonDecode(res.body);
      final List<String> serverIds = List<String>.from(data['bundle_ids'] ?? []);

      final db = await StarlightVault.instance.database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shop_bundles (
          id TEXT PRIMARY KEY,
          type TEXT,
          title TEXT,
          description TEXT,
          price REAL,
          currency TEXT,
          is_popular INTEGER DEFAULT 0,
          products TEXT,
          gold INTEGER DEFAULT 0,
          silver INTEGER DEFAULT 0,
          ai_credits INTEGER DEFAULT 0,
          updated_at TEXT
        )
      ''');

      final List<Map<String, dynamic>> localRows = await db.query('shop_bundles', columns: ['id']);
      final List<String> localIds = localRows.map((r) => r['id'] as String).toList();

      for (final id in localIds) {
        if (!serverIds.contains(id)) {
          await db.delete('shop_bundles', where: 'id = ?', whereArgs: [id]);
          debugPrint('ShopService: Deleted stale local bundle - $id');
        }
      }

      for (final id in serverIds) {
        final detailRes = await http.get(
          Uri.parse('${StarlightConstants.apiBaseUrl}/shop/bundles/$id'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (detailRes.statusCode == 200) {
          final b = jsonDecode(detailRes.body);
          await db.insert('shop_bundles', {
            'id': b['id'],
            'type': b['type'],
            'title': b['title'],
            'description': b['description'],
            'price': (b['price'] ?? 0.0).toDouble(),
            'currency': b['currency'] ?? 'PKR',
            'is_popular': (b['is_popular'] == true) ? 1 : 0,
            'products': jsonEncode(b['products'] ?? []),
            'gold': b['gold'] ?? 0,
            'silver': b['silver'] ?? 0,
            'ai_credits': b['ai_credits'] ?? 0,
            'updated_at': b['updated_at'] ?? DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          debugPrint('ShopService: Synced and cached bundle - $id');
        }
      }
    } catch (e) {
      debugPrint('ShopService: syncBundles error - $e');
    }
  }

  Future<List<ShopProduct>> getProducts() async {
    try {
      final db = await StarlightVault.instance.database;
      final List<Map<String, dynamic>> rows = await db.query('shop_bundles');

      if (rows.isEmpty) return [];

      return rows.map((b) {
        final String type = b['type'] ?? 'currency';
        final List<dynamic> productsList = b['products'] != null
            ? jsonDecode(b['products'])
            : [];

        final Map<String, String> specs = {};
        if (type == 'subscription' || type == 'feature' || type == 'tool') {
          specs['Features'] = productsList.join(', ');
        } else {
          if ((b['gold'] ?? 0) > 0) specs['Gold'] = b['gold'].toString();
          if ((b['silver'] ?? 0) > 0) specs['Silver'] = b['silver'].toString();
          if ((b['ai_credits'] ?? 0) > 0) specs['AI Credits'] = b['ai_credits'].toString();
        }

        IconData icon = Icons.shopping_bag;
        Color color = Colors.blue;
        ShopCategory category;

        if (type == 'subscription') {
          icon = Icons.star;
          color = Colors.purple;
          category = ShopCategory.subscription;
        } else if (type == 'feature') {
          icon = Icons.extension;
          color = Colors.teal;
          category = ShopCategory.feature;
        } else if (type == 'tool') {
          icon = Icons.handyman;
          color = Colors.cyan;
          category = ShopCategory.tool;
        } else {
          icon = Icons.monetization_on;
          color = Colors.amber;
          category = ShopCategory.credits;
        }

        return ShopProduct(
          id: b['id'] ?? '',
          title: b['title'] ?? '',
          description: b['description'] ?? '',
          price: (b['price'] ?? 0.0).toDouble(),
          currency: b['currency'] ?? 'PKR',
          icon: icon,
          color: color,
          category: category,
          isPopular: (b['is_popular'] == 1),
          specs: specs,
        );
      }).toList();
    } catch (e) {
      debugPrint('ShopService: getProducts error - $e');
      return [];
    }
  }

  Future<ShopWallet> getWallet() async {
    try {
      final token = await _token();
      if (token == null) return _mockWallet();
      final res = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/subscription/wallet'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return ShopWallet(
          gold: data['gold_coins'] ?? data['gold'] ?? 0,
          silver: data['silver_coins'] ?? data['silver'] ?? 0,
          aiCredits: data['ai_credits'] ?? data['ai'] ?? 0,
          lastUpdated: DateTime.parse(data['last_updated'] ?? DateTime.now().toIso8601String()),
        );
      }
      return _mockWallet();
    } catch (e) {
      debugPrint('ShopService: getWallet error - $e');
      return _mockWallet();
    }
  }

  Future<List<ShopTransaction>> getTransactions() async {
    try {
      final token = await _token();
      if (token == null) return [];
      final res = await http.get(
        Uri.parse('${StarlightConstants.apiBaseUrl}/subscription/wallet/transactions'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['transactions'] as List).map((t) => ShopTransaction(
          id: t['id'] ?? '',
          type: t['type'] ?? '',
          description: t['description'] ?? '',
          goldAmount: t['gold_amount'] ?? 0,
          silverAmount: t['silver_amount'] ?? 0,
          aiCreditsAmount: t['ai_credits_amount'] ?? 0,
          createdAt: DateTime.parse(t['created_at']),
        )).toList();
      }
      return [];
    } catch (e) {
      debugPrint('ShopService: getTransactions error - $e');
      return [];
    }
  }

  ShopWallet _mockWallet() => ShopWallet(
    gold: 150,
    silver: 750,
    aiCredits: 25,
    lastUpdated: DateTime.now(),
  );
}
