import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database_helper.dart';
import '../models/book_models.dart';

class LibraryDownloadService {
  static final StarlightVault _vault = StarlightVault.instance;

  /// 📥 Download a library publication and save it both on local disk and SQLite
  static Future<void> downloadAndSaveBook(Book book) async {
    final downloadUrl = book.absoluteFileUrl;
    if (downloadUrl.isEmpty) throw Exception("Document has no file URL");

    // 1. Fetch file bytes from server
    final response = await http.get(Uri.parse(downloadUrl));
    if (response.statusCode != 200) {
      throw Exception("Download failed: Server returned HTTP ${response.statusCode}");
    }

    // 2. Save file to Application Documents directory (non-temp, persistent)
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/library_downloads');
    await downloadDir.create(recursive: true);

    final ext = book.resolvedExt.isEmpty ? 'pdf' : book.resolvedExt;
    final localFilePath = '${downloadDir.path}/${book.id}.$ext';
    final file = File(localFilePath);
    await file.writeAsBytes(response.bodyBytes);

    // 3. Save metadata to SQLite
    final db = await _vault.database;
    await db.insert(
      'library_downloads',
      {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'topic': book.topic,
        'doc_type': book.docType,
        'local_path': localFilePath,
        'file_name': book.fileName,
        'file_ext': book.resolvedExt,
        'file_size': book.fileSize,
        'channel_id': book.channelId,
        'channel_name': book.channelName,
        'channel_pic': book.channelPic,
        'created_at': book.createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 📂 Query the local DB for all persistent offline downloads
  static Future<List<Book>> fetchDownloadedBooks() async {
    final db = await _vault.database;
    final List<Map<String, dynamic>> results = await db.query('library_downloads', orderBy: 'title ASC');

    return results.map((map) {
      return Book(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        author: map['author'] ?? 'Unknown',
        topic: map['topic'] ?? 'General',
        fileUrl: map['local_path'] ?? '', // Points directly to local path on disk!
        docType: map['doc_type'] ?? 'book',
        channelId: map['channel_id'] ?? '',
        channelName: map['channel_name'] ?? 'Local Library',
        channelPic: map['channel_pic'] ?? 'default_avatar',
        uploaderId: '',
        institutionId: '',
        likesCount: 0,
        dislikesCount: 0,
        reportsCount: 0,
        viewsCount: 0,
        createdAt: map['created_at'] ?? '',
        userLiked: false,
        userDisliked: false,
        userReported: false,
        userSaved: true, // Mark as saved/bookmarked so save operations can trigger unsaving
        fileName: map['file_name'] ?? '',
        fileExt: map['file_ext'] ?? '',
        fileSize: map['file_size'] ?? 0,
        mimeType: '',
      );
    }).toList();
  }

  /// 🔍 Check if a publication is already downloaded and available offline
  static Future<bool> isBookDownloaded(String bookId) async {
    final db = await _vault.database;
    final results = await db.query(
      'library_downloads',
      where: 'id = ?',
      whereArgs: [bookId],
    );
    return results.isNotEmpty;
  }

  /// 🔍 Get local path of a downloaded book
  static Future<String?> getLocalPath(String bookId) async {
    final db = await _vault.database;
    final results = await db.query(
      'library_downloads',
      columns: ['local_path'],
      where: 'id = ?',
      whereArgs: [bookId],
    );
    if (results.isEmpty) return null;
    return results.first['local_path'] as String?;
  }

  /// 🗑️ Delete downloaded note/book file and its database record
  static Future<void> deleteDownloadedBook(String bookId) async {
    final localPath = await getLocalPath(bookId);
    if (localPath != null) {
      try {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    final db = await _vault.database;
    await db.delete(
      'library_downloads',
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }
}
