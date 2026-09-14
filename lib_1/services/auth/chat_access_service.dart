import '../../../core/storage.dart';
import 'firebase_phone_service.dart';
import 'package:flutter/foundation.dart';

class ChatAccessService {
  /// Check if user has chat access
  static Future<bool> hasChatAccess() async {
    try {
      // First check local preference
      bool isChatVerified = await StarlightStorage.getChatVerified() ?? false;
      String? savedPhone = await StarlightStorage.getVerifiedPhone();
      
      if (kDebugMode) {
        debugPrint('🏛️ Local chat verification status: $isChatVerified, phone: $savedPhone');
      }
      
      // If locally verified with phone number, trust local state (WhatsApp-style)
      if (isChatVerified && savedPhone != null && savedPhone.isNotEmpty) {
        return true;
      }
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error checking chat access: $e');
      }
      return false;
    }
  }

  /// Check if user is verified for chat (alias for hasChatAccess)
  static Future<bool> isChatVerified() async {
    return await hasChatAccess();
  }

  /// Get chat access destination screen
  static Future<String> getChatAccessRoute() async {
    bool hasAccess = await hasChatAccess();
    
    if (hasAccess) {
      return '/owner/chat/list';
    } else {
      return '/owner/chat/verification';
    }
  }

  /// Clear chat access (for logout or revocation)
  static Future<void> clearChatAccess() async {
    try {
      await StarlightStorage.setChatVerified(false);
      await _clearFirebaseData();
      
      if (kDebugMode) {
        debugPrint('🏛️ Chat access cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error clearing chat access: $e');
      }
    }
  }

  /// Refresh chat access status from server (use for manual refresh only)
  static Future<bool> refreshChatAccess() async {
    try {
      bool serverVerified = await FirebasePhoneService.checkServerVerificationStatus();
      await StarlightStorage.setChatVerified(serverVerified);
      
      if (kDebugMode) {
        debugPrint('🏛️ Chat access refreshed: $serverVerified');
      }
      
      return serverVerified;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error refreshing chat access: $e');
      }
      return false;
    }
  }

  /// Get user's verified phone number
  static Future<String?> getVerifiedPhoneNumber() async {
    try {
      // Check Firebase first
      if (FirebasePhoneService.currentUser != null) {
        return FirebasePhoneService.currentUser!.phoneNumber;
      }
      
      // Fallback to local storage
      return await StarlightStorage.getVerifiedPhone();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error getting verified phone number: $e');
      }
      return null;
    }
  }

  /// Check if Firebase user is authenticated
  static bool isFirebaseAuthenticated() {
    return FirebasePhoneService.currentUser != null;
  }

  /// Get Firebase user ID
  static Future<String?> getFirebaseUserId() async {
    try {
      // Check Firebase first
      if (FirebasePhoneService.currentUser != null) {
        return FirebasePhoneService.currentUser!.uid;
      }
      
      // Fallback to local storage
      return await StarlightStorage.getFirebaseUserId();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error getting Firebase user ID: $e');
      }
      return null;
    }
  }

  /// Clear Firebase data from local storage
  static Future<void> _clearFirebaseData() async {
    try {
      await StarlightStorage.setFirebaseUserId('');
      await StarlightStorage.setVerifiedPhone('');
      await StarlightStorage.setFirebaseToken('');
      
      // Sign out from Firebase
      await FirebasePhoneService.signOut();
      
      if (kDebugMode) {
        debugPrint('🏛️ Firebase data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error clearing Firebase data: $e');
      }
    }
  }

  /// Initialize chat access check (call on app start)
  static Future<void> initialize() async {
    try {
      // First check if we have a verified phone number stored locally
      final String? verifiedPhone = await StarlightStorage.getVerifiedPhone();
      final bool isVerified = await StarlightStorage.getChatVerified() ?? false;
      
      if (verifiedPhone != null && verifiedPhone.isNotEmpty && isVerified) {
        // Already verified locally, trust local state (WhatsApp-style)
        if (kDebugMode) {
          debugPrint('🏛️ Chat access initialized: Using offline verified phone: $verifiedPhone');
        }
        return;
      }
      
      // No local verification, check server if we have Firebase user
      if (FirebasePhoneService.currentUser != null) {
        bool serverVerified = await FirebasePhoneService.checkServerVerificationStatus();
        await StarlightStorage.setChatVerified(serverVerified);
        
        if (kDebugMode) {
          debugPrint('🏛️ Chat access initialized with server verification: $serverVerified');
        }
      } else {
        // No Firebase user and no local verification
        await StarlightStorage.setChatVerified(false);
        
        if (kDebugMode) {
          debugPrint('🏛️ Chat access initialized: No verification found');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🏛️ Error initializing chat access: $e');
      }
    }
  }
}
