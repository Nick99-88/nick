import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/checkout.dart';
import '../models/field_config.dart';
import 'database_service.dart';

const String _baseUrl = 'https://api.institution.site';

class ApiService implements DatabaseService {
  String? _token;

  @override
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  bool get isAuthenticated => _token != null;

  /// Authenticate with email/password and store JWT token.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'app_id': 'library_management'}),
    );
    if (res.statusCode != 200) {
      final detail = jsonDecode(res.body)['detail'] as String? ?? 'Login failed';
      throw Exception(detail);
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    _token = data['access_token'] as String?;
    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
    }
    return data;
  }

  /// Upload all local data (config + books + checkouts) to the server.
  Future<void> uploadAllData(String exportedJson) async {
    if (_token == null) throw Exception('Not authenticated');

    final export = jsonDecode(exportedJson) as Map<String, dynamic>;

    // Upload config
    final config = export['library_config'];
    if (config != null) {
      await _authPost('/library/config', config as Map<String, dynamic>);
    }

    // Upload books
    final books = export['books'] as List? ?? [];
    for (final b in books) {
      final book = b as Map<String, dynamic>;
      try {
        await _authPost('/library/management/books', book);
      } catch (_) {
        // Skip individual book failures and continue
      }
    }

    // Upload checkouts
    final checkouts = export['checkouts'] as List? ?? [];
    for (final c in checkouts) {
      final checkout = c as Map<String, dynamic>;
      try {
        await _authPost('/library/checkout', checkout);
      } catch (_) {
        // Skip individual checkout failures and continue
      }
    }
  }

  /// Import all data from server and return as export-format JSON string.
  Future<String> importAllData() async {
    if (_token == null) throw Exception('Not authenticated');

    final res = await _authGet('/library/management/export');
    if (res.statusCode != 200) throw Exception('Failed to import data from server');
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(res.body));
  }

  Future<http.Response> _authGet(String path) async {
    final res = await http.get(Uri.parse('$_baseUrl$path'), headers: _headers);
    if (res.statusCode == 401) throw Exception('Unauthorized');
    return res;
  }

  Future<http.Response> _authPost(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw Exception('Unauthorized');
    return res;
  }

  Future<http.Response> _authDelete(String path) async {
    final res = await http.delete(Uri.parse('$_baseUrl$path'), headers: _headers);
    if (res.statusCode == 401) throw Exception('Unauthorized');
    return res;
  }

  @override
  Future<void> saveLibraryConfig(LibraryConfig config) async {
    try {
      await _authPost('/library/config', config.toJson());
    } catch (_) {
      // fallback: keep local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('library_config', jsonEncode(config.toJson()));
    }
  }

  @override
  Future<LibraryConfig?> loadLibraryConfig() async {
    try {
      final res = await _authGet('/library/config');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return LibraryConfig.fromJson(data);
      }
    } catch (_) {
      // fallback to local
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('library_config');
    if (raw == null) return null;
    return LibraryConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> addBook(Book book) async {
    await _authPost('/library/upload', {
      'title': book.title,
      'author': book.author,
      'description': book.description ?? '',
      'topic': 'General',
      'doc_type': 'book',
      'almirah_id': book.almirahId,
      'cabin_id': book.cabinId,
      'field_values': book.fieldValues,
    });
  }

  @override
  Future<List<Book>> getBooks({String? search}) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    final uri =
        Uri.parse('$_baseUrl/library/items').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List? ?? [];
    return items.map((i) {
      final m = i as Map<String, dynamic>;
      return Book(
        id: m['_id']?.toString() ?? m['id']?.toString() ?? '',
        title: m['title'] as String? ?? '',
        author: m['author'] as String? ?? '',
        description: m['description'] as String?,
        totalCopies: m['total_copies'] as int?,
        availableCopies: m['available_copies'] as int?,
        almirahId: m['almirah_id'] as String?,
        cabinId: m['cabin_id'] as String?,
        fieldValues: (m['field_values'] as Map<String, dynamic>?) ?? {},
      );
    }).toList();
  }

  @override
  Future<Book?> getBook(String id) async {
    final res = await _authGet('/library/item/$id');
    if (res.statusCode != 200) return null;
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return Book(
      id: m['_id']?.toString() ?? m['id']?.toString() ?? '',
      title: m['title'] as String? ?? '',
      author: m['author'] as String? ?? '',
      description: m['description'] as String?,
      totalCopies: m['total_copies'] as int?,
      availableCopies: m['available_copies'] as int?,
      almirahId: m['almirah_id'] as String?,
      cabinId: m['cabin_id'] as String?,
      fieldValues: (m['field_values'] as Map<String, dynamic>?) ?? {},
    );
  }

  @override
  Future<void> updateBook(Book book) async {
    await _authPost('/library/${book.id}/update', book.toJson());
  }

  @override
  Future<void> deleteBook(String id) async {
    await _authDelete('/library/$id');
  }

  @override
  Future<int> getBookCount() async {
    final res = await _authGet('/library/items?limit=1');
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['items'] as List? ?? [];
    return items.length;
  }

  // -- Checkouts (stubs for online mode) --

  @override
  Future<void> checkoutBook(Checkout checkout) async {
    await _authPost('/library/checkout', checkout.toJson());
  }

  @override
  Future<void> returnBook(String checkoutId) async {
    await _authPost('/library/checkout/$checkoutId/return', {});
  }

  @override
  Future<List<Checkout>> getActiveCheckouts() async {
    final res = await _authGet('/library/checkouts/active');
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Checkout.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Checkout>> getAllCheckouts() async {
    final res = await _authGet('/library/checkouts');
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Checkout.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Checkout>> getCheckoutsForBook(String bookId) async {
    final res = await _authGet('/library/checkouts?book_id=$bookId');
    if (res.statusCode != 200) return [];
    final list = jsonDecode(res.body) as List;
    return list.map((e) => Checkout.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<int> getActiveCheckoutCount() async {
    final list = await getActiveCheckouts();
    return list.length;
  }

  // -- Export / Clear --

  @override
  Future<String> exportData() async {
    final books = await getBooks();
    final checkouts = await getAllCheckouts();
    final prefs = await SharedPreferences.getInstance();
    final configRaw = prefs.getString('library_config');

    final export = {
      'exported_at': DateTime.now().toIso8601String(),
      'library_config': configRaw != null ? jsonDecode(configRaw) : null,
      'books': books.map((b) => b.toJson()).toList(),
      'checkouts': checkouts.map((c) => c.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(export);
  }

  @override
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('library_config');
    // Backend clear would need a dedicated endpoint
    throw UnimplementedError('Clear all data not available in online mode');
  }
}
