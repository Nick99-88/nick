import '../models/book.dart';
import '../models/checkout.dart';
import '../models/field_config.dart';

abstract class DatabaseService {
  Future<void> initialize();

  // Field configuration
  Future<void> saveLibraryConfig(LibraryConfig config);
  Future<LibraryConfig?> loadLibraryConfig();

  // Books
  Future<void> addBook(Book book);
  Future<List<Book>> getBooks({String? search});
  Future<Book?> getBook(String id);
  Future<void> updateBook(Book book);
  Future<void> deleteBook(String id);
  Future<int> getBookCount();

  // Checkouts
  Future<void> checkoutBook(Checkout checkout);
  Future<void> returnBook(String checkoutId);
  Future<List<Checkout>> getActiveCheckouts();
  Future<List<Checkout>> getAllCheckouts();
  Future<List<Checkout>> getCheckoutsForBook(String bookId);
  Future<int> getActiveCheckoutCount();

  // Export / Clear
  Future<String> exportData();
  Future<void> clearAllData();
}
