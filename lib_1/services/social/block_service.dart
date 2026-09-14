import 'dart:async';
import 'package:starlight_flutter/services/api_service.dart';

class BlockService {
  static final BlockService _instance = BlockService._internal();
  factory BlockService() => _instance;
  BlockService._internal();

  // Cache: set of user IDs who have blocked me
  final Set<String> _blockedByUsers = {};
  
  // Cache: set of user IDs I have blocked
  final Set<String> _iBlockedUsers = {};
  
  // Cache: block details (user_id -> block info)
  final Map<String, Map<String, dynamic>> _blockDetails = {};
  
  // Timer for periodic cleanup
  Timer? _cleanupTimer;

  Set<String> get blockedByUsers => Set.from(_blockedByUsers);
  Set<String> get iBlockedUsers => Set.from(_iBlockedUsers);

  /// Initialize block service - fetch blocked lists
  Future<void> initialize() async {
    await Future.wait([
      fetchBlockedByUsers(),
      fetchIBlockedUsers(),
    ]);
    
    // Start periodic cleanup every 5 minutes
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(minutes: 5), (_) => _cleanupExpiredBlocks());
  }

  /// Fetch all users who have blocked me
  Future<void> fetchBlockedByUsers() async {
    try {
      final response = await ApiService.get('/block/blocked-by');
      final List<dynamic> users = response['blocked_by_users'] ?? [];
      
      _blockedByUsers.clear();
      for (final user in users) {
        final userId = user['blocked_by_user_id'] as String;
        _blockedByUsers.add(userId);
        _blockDetails['blocked_by_$userId'] = user;
      }
      
      print('🔍 BlockService: Fetched ${_blockedByUsers.length} users who blocked me');
    } catch (e) {
      print('🔍 BlockService: Error fetching blocked by users - $e');
    }
  }

  /// Fetch all users I have blocked
  Future<void> fetchIBlockedUsers() async {
    try {
      final response = await ApiService.get('/block/blocked');
      final List<dynamic> users = response['blocked_users'] ?? [];
      
      _iBlockedUsers.clear();
      for (final user in users) {
        final userId = user['user_id'] as String;
        _iBlockedUsers.add(userId);
        _blockDetails['i_blocked_$userId'] = user;
      }
      
      print('🔍 BlockService: Fetched ${_iBlockedUsers.length} users I blocked');
    } catch (e) {
      print('🔍 BlockService: Error fetching blocked users - $e');
    }
  }

  /// Block a user with duration
  Future<bool> blockUser(String userId, String duration) async {
    try {
      final response = await ApiService.post('/block/$userId', {
        'duration': duration,
      });
      
      if (response['success'] == true) {
        _iBlockedUsers.add(userId);
        _blockDetails['i_blocked_$userId'] = {
          'user_id': userId,
          'duration': duration,
          'blocked_at': response['blocked_at'],
          'expires_at': response['expires_at'],
          'block_id': response['block_id'],
        };
        return true;
      }
      return false;
    } catch (e) {
      print('🔍 BlockService: Error blocking user - $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String userId) async {
    try {
      final response = await ApiService.delete('/block/$userId');
      
      if (response['success'] == true) {
        _iBlockedUsers.remove(userId);
        _blockDetails.remove('i_blocked_$userId');
        return true;
      }
      return false;
    } catch (e) {
      print('🔍 BlockService: Error unblocking user - $e');
      return false;
    }
  }

  /// Check if a user is blocked (by me or by them)
  Future<Map<String, bool>> checkBlockStatus(String userId) async {
    try {
      final response = await ApiService.get('/block/check/$userId');
      
      return {
        'i_blocked': response['i_blocked'] ?? false,
        'blocked_by_them': response['blocked_by_them'] ?? false,
        'blocked': response['blocked'] ?? false,
      };
    } catch (e) {
      print('🔍 BlockService: Error checking block status - $e');
      return {
        'i_blocked': false,
        'blocked_by_them': false,
        'blocked': false,
      };
    }
  }

  /// Check if I am blocked by a specific user (cached)
  bool amIBlockedBy(String userId) {
    return _blockedByUsers.contains(userId);
  }

  /// Check if I have blocked a user (cached)
  bool haveIBlocked(String userId) {
    return _iBlockedUsers.contains(userId);
  }

  /// Check if there's any block between two users (cached)
  bool isBlocked(String otherUserId) {
    return _iBlockedUsers.contains(otherUserId) || _blockedByUsers.contains(otherUserId);
  }

  /// Get block details for a user
  Map<String, dynamic>? getBlockDetails(String userId) {
    return _blockDetails['i_blocked_$userId'] ?? _blockDetails['blocked_by_$userId'];
  }

  /// Get the block time for a user who blocked me
  String? getBlockedByTime(String userId) {
    final details = _blockDetails['blocked_by_$userId'];
    return details?['blocked_at'];
  }

  /// Cleanup expired blocks
  Future<void> _cleanupExpiredBlocks() async {
    try {
      await ApiService.post('/block/cleanup-expired', {});
      
      // Refresh the lists
      await Future.wait([
        fetchBlockedByUsers(),
        fetchIBlockedUsers(),
      ]);
    } catch (e) {
      print('🔍 BlockService: Error cleaning up expired blocks - $e');
    }
  }

  /// Refresh all block data
  Future<void> refresh() async {
    await initialize();
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
  }
}

// Singleton instance
final blockService = BlockService();
