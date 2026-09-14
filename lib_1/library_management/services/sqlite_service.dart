import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../models/checkout.dart';
import '../models/field_config.dart';
import 'database_service.dart';

class SqliteService implements DatabaseService {
  Database? _db;
  bool _initializing = false;
  static bool _ffiInitialized = false;

  static void ensureFfi() {
    if (_ffiInitialized) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _ffiInitialized = true;
  }

  @override
  Future<void> initialize() async {
    if (_db != null) return;
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    _initializing = true;
    ensureFfi();
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'library.db');
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            author TEXT DEFAULT '',
            isbn TEXT,
            description TEXT,
            total_copies INTEGER,
            available_copies INTEGER,
            almirah_id TEXT,
            cabin_id TEXT,
            created_at TEXT NOT NULL,
            field_values TEXT NOT NULL DEFAULT '{}'
          )
        ''');
        await db.execute('''
          CREATE TABLE checkouts (
            id TEXT PRIMARY KEY,
            book_id TEXT NOT NULL,
            book_title TEXT DEFAULT '',
            book_author TEXT DEFAULT '',
            client_name TEXT NOT NULL,
            client_phone TEXT,
            checkout_date TEXT NOT NULL,
            return_date TEXT,
            notes TEXT,
            extra_fields TEXT NOT NULL DEFAULT '{}'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS checkouts (
              id TEXT PRIMARY KEY,
              book_id TEXT NOT NULL,
              book_title TEXT DEFAULT '',
              book_author TEXT DEFAULT '',
              client_name TEXT NOT NULL,
              client_phone TEXT,
              checkout_date TEXT NOT NULL,
              return_date TEXT,
              notes TEXT,
              extra_fields TEXT NOT NULL DEFAULT '{}'
            )
          ''');
        }
      },
    );
    _initializing = false;
  }

  Future<Database> _getDb() async {
    if (_db == null) await initialize();
    final db = _db!;
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='checkouts'");
    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS checkouts (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          book_title TEXT DEFAULT '',
          book_author TEXT DEFAULT '',
          client_name TEXT NOT NULL,
          client_phone TEXT,
          checkout_date TEXT NOT NULL,
          return_date TEXT,
          notes TEXT,
          extra_fields TEXT NOT NULL DEFAULT '{}'
        )
      ''');
    } else {
      try {
        await db.rawQuery('SELECT extra_fields FROM checkouts LIMIT 1');
      } catch (_) {
        await db.execute('ALTER TABLE checkouts ADD COLUMN extra_fields TEXT NOT NULL DEFAULT \'{}\'');
      }
    }
    return db;
  }

  @override
  Future<void> saveLibraryConfig(LibraryConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('library_config', jsonEncode(config.toJson()));
  }

  @override
  Future<LibraryConfig?> loadLibraryConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('library_config');
    if (raw == null) return null;
    return LibraryConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> addBook(Book book) async {
    final db = await _getDb();
    await db.insert('books', {
      'id': book.id,
      'title': book.title,
      'author': book.author,
      'isbn': book.isbn,
      'description': book.description,
      'total_copies': book.totalCopies,
      'available_copies': book.availableCopies,
      'almirah_id': book.almirahId,
      'cabin_id': book.cabinId,
      'created_at': book.createdAt.toIso8601String(),
      'field_values': jsonEncode(book.fieldValues),
    });
  }

  @override
  Future<List<Book>> getBooks({String? search}) async {
    final db = await _getDb();
    List<Map<String, dynamic>> rows;
    if (search != null && search.isNotEmpty) {
      rows = await db.query(
        'books',
        where: 'title LIKE ? OR author LIKE ? OR isbn LIKE ?',
        whereArgs: ['%$search%', '%$search%', '%$search%'],
        orderBy: 'created_at DESC',
      );
    } else {
      rows = await db.query('books', orderBy: 'created_at DESC');
    }
    return rows.map((r) => _rowToBook(r)).toList();
  }

  @override
  Future<Book?> getBook(String id) async {
    final db = await _getDb();
    final rows = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToBook(rows.first);
  }

  @override
  Future<void> updateBook(Book book) async {
    final db = await _getDb();
    await db.update(
      'books',
      {
        'title': book.title,
        'author': book.author,
        'isbn': book.isbn,
        'description': book.description,
        'total_copies': book.totalCopies,
        'available_copies': book.availableCopies,
        'almirah_id': book.almirahId,
        'cabin_id': book.cabinId,
        'field_values': jsonEncode(book.fieldValues),
      },
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  @override
  Future<void> deleteBook(String id) async {
    final db = await _getDb();
    await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> getBookCount() async {
    final db = await _getDb();
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM books');
    return result.first['c'] as int;
  }

  // -- Checkouts --

  @override
  Future<void> checkoutBook(Checkout checkout) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.insert('checkouts', {
        'id': checkout.id,
        'book_id': checkout.bookId,
        'book_title': checkout.bookTitle,
        'book_author': checkout.bookAuthor,
        'client_name': checkout.clientName,
        'client_phone': checkout.clientPhone,
        'checkout_date': checkout.checkoutDate.toIso8601String(),
        'return_date': null,
        'notes': checkout.notes,
        'extra_fields': jsonEncode(checkout.extraFields),
      });
      await txn.rawUpdate(
        'UPDATE books SET available_copies = available_copies - 1 WHERE id = ? AND available_copies > 0',
        [checkout.bookId],
      );
    });
  }

  @override
  Future<void> returnBook(String checkoutId) async {
    final db = await _getDb();
    final rows = await db.query('checkouts', where: 'id = ?', whereArgs: [checkoutId]);
    if (rows.isEmpty) return;
    final co = rows.first;
    await db.transaction((txn) async {
      await txn.update(
        'checkouts',
        {'return_date': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [checkoutId],
      );
      await txn.rawUpdate(
        'UPDATE books SET available_copies = available_copies + 1 WHERE id = ?',
        [co['book_id']],
      );
    });
  }

  @override
  Future<List<Checkout>> getActiveCheckouts() async {
    final db = await _getDb();
    final rows = await db.query('checkouts',
        where: 'return_date IS NULL', orderBy: 'checkout_date DESC');
    return rows.map((r) => _rowToCheckout(r)).toList();
  }

  @override
  Future<List<Checkout>> getAllCheckouts() async {
    final db = await _getDb();
    final rows = await db.query('checkouts', orderBy: 'checkout_date DESC');
    return rows.map((r) => _rowToCheckout(r)).toList();
  }

  @override
  Future<List<Checkout>> getCheckoutsForBook(String bookId) async {
    final db = await _getDb();
    final rows = await db.query('checkouts',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'checkout_date DESC');
    return rows.map((r) => _rowToCheckout(r)).toList();
  }

  @override
  Future<int> getActiveCheckoutCount() async {
    final db = await _getDb();
    final result =
        await db.rawQuery('SELECT COUNT(*) as c FROM checkouts WHERE return_date IS NULL');
    return result.first['c'] as int;
  }

  // -- Export / Clear --

  @override
  Future<String> exportData() async {
    final db = await _getDb();
    final books = await db.query('books', orderBy: 'created_at DESC');
    final checkouts = await db.query('checkouts', orderBy: 'checkout_date DESC');
    final prefs = await SharedPreferences.getInstance();
    final configRaw = prefs.getString('library_config');

    final export = {
      'exported_at': DateTime.now().toIso8601String(),
      'library_config': configRaw != null ? jsonDecode(configRaw) : null,
      'books': books,
      'checkouts': checkouts,
    };
    return const JsonEncoder.withIndent('  ').convert(export);
  }

  @override
  Future<void> clearAllData() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete('checkouts');
      await txn.delete('books');
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('library_config');
  }

  Book _rowToBook(Map<String, dynamic> row) => Book(
        id: row['id'] as String,
        title: row['title'] as String,
        author: row['author'] as String? ?? '',
        isbn: row['isbn'] as String?,
        description: row['description'] as String?,
        totalCopies: row['total_copies'] as int?,
        availableCopies: row['available_copies'] as int?,
        almirahId: row['almirah_id'] as String?,
        cabinId: row['cabin_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        fieldValues: jsonDecode(row['field_values'] as String) as Map<String, dynamic>,
      );

  Checkout _rowToCheckout(Map<String, dynamic> row) => Checkout(
        id: row['id'] as String,
        bookId: row['book_id'] as String,
        bookTitle: row['book_title'] as String? ?? '',
        bookAuthor: row['book_author'] as String? ?? '',
        clientName: row['client_name'] as String,
        clientPhone: row['client_phone'] as String?,
        checkoutDate: DateTime.parse(row['checkout_date'] as String),
        returnDate: row['return_date'] != null ? DateTime.parse(row['return_date'] as String) : null,
        notes: row['notes'] as String?,
        extraFields: row['extra_fields'] != null
            ? jsonDecode(row['extra_fields'] as String) as Map<String, dynamic>
            : {},
      );
}
