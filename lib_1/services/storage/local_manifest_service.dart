import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:starlight_flutter/core/storage.dart';

/// 🏛️ Local Manifest Service for JSON-based file tracking
/// Replaces SQLite with lightweight JSON schema
class LocalManifestService {
  static const String _manifestFileName = 'media_manifest.json';
  
  /// 🏛️ Get manifest file path
  static Future<File> _getManifestFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_manifestFileName');
  }
  
  /// 🏛️ Load existing manifest
  static Future<Map<String, dynamic>> loadManifest() async {
    try {
      final file = await _getManifestFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final manifest = jsonDecode(content) as Map<String, dynamic>;
        print('🏛️ Local Manifest: Loaded manifest with ${manifest['messages']?.length ?? 0} messages');
        return manifest;
      }
      return {'messages': []};
    } catch (e) {
      print('🏛️ Local Manifest: Error loading manifest - $e');
      return {'messages': []};
    }
  }
  
  /// 🏛️ Save manifest to storage
  static Future<void> saveManifest(Map<String, dynamic> manifest) async {
    try {
      final file = await _getManifestFile();
      final content = jsonEncode(manifest);
      await file.writeAsString(content);
      print('🏛️ Local Manifest: Saved manifest with ${manifest['messages']?.length ?? 0} messages');
    } catch (e) {
      print('🏛️ Local Manifest: Error saving manifest - $e');
    }
  }
  
  /// 🏛️ Add new media entry to manifest
  static Future<void> addMediaEntry({
    required String msgId,
    required String direction, // 'sent' or 'received'
    required String localUri,
    String? serverLink,
    String? thumbnailBlob,
    bool isDownloaded = false,
    int? fileSizeTotal,
    int? bytesDownloaded,
  }) async {
    final manifest = await loadManifest();
    
    final newEntry = {
      'msg_id': msgId,
      'direction': direction,
      'local_uri': localUri,
      'server_link': serverLink,
      'thumbnail_blob': thumbnailBlob,
      'is_downloaded': isDownloaded,
      'file_size_total': fileSizeTotal,
      'bytes_downloaded': bytesDownloaded,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    manifest['messages'].add(newEntry);
    await saveManifest(manifest);
    
    print('🏛️ Local Manifest: Added $direction entry for msg $msgId');
  }
  
  /// 🏛️ Update download progress for an entry
  static Future<void> updateDownloadProgress(String msgId, int bytesDownloaded, int fileSizeTotal) async {
    final manifest = await loadManifest();
    
    final messages = manifest['messages'] as List<dynamic>;
    final entryIndex = messages.indexWhere((msg) => msg['msg_id'] == msgId);
    
    if (entryIndex != -1) {
      messages[entryIndex]['bytes_downloaded'] = bytesDownloaded;
      messages[entryIndex]['file_size_total'] = fileSizeTotal;
      messages[entryIndex]['is_downloaded'] = bytesDownloaded >= fileSizeTotal;
      
      await saveManifest(manifest);
      print('🏛️ Local Manifest: Updated progress for msg $msgId: ${bytesDownloaded}/$fileSizeTotal');
    }
  }
  
  /// 🏛️ Get messages for current user
  static Future<List<Map<String, dynamic>>> getUserMessages() async {
    final manifest = await loadManifest();
    final messages = manifest['messages'] as List<dynamic>;
    
    // Sort by creation date (newest first)
    messages.sort((a, b) => 
        DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']))
    );
    
    return messages.cast<Map<String, dynamic>>();
  }
  
  /// 🏛️ Get messages between current user and another user
  static Future<List<Map<String, dynamic>>> getChatMessages(String otherUserId) async {
    final manifest = await loadManifest();
    final messages = manifest['messages'] as List<dynamic>;
    final currentUserId = await StarlightStorage.getUserId();
    
    // Filter messages involving current user and other user
    final chatMessages = messages.where((msg) {
      // This would need sender_id in the message schema
      // For now, return all messages involving the current user
      return true; // TODO: Implement proper filtering
    }).toList();
    
    // Sort by creation date (oldest first for chat display)
    chatMessages.sort((a, b) => 
        DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']))
    );
    
    return chatMessages.cast<Map<String, dynamic>>();
  }
  
  /// 🏛️ Clear manifest (for testing)
  static Future<void> clearManifest() async {
    try {
      final file = await _getManifestFile();
      if (await file.exists()) {
        await file.delete();
        print('🏛️ Local Manifest: Cleared manifest');
      }
    } catch (e) {
      print('🏛️ Local Manifest: Error clearing manifest - $e');
    }
  }
}
