import 'dart:async';
import 'package:starlight_flutter/services/socket/enhanced_socket_service.dart';
import 'package:starlight_flutter/chat_system/services/socket_event_bus.dart';

class ContactVerificationResult {
  final bool verified;
  final bool exists;
  final String? profileImageUrl;
  final String? peerUserId;
  final String? contactName;

  const ContactVerificationResult({
    required this.verified,
    required this.exists,
    this.profileImageUrl,
    this.peerUserId,
    this.contactName,
  });
}

class ContactVerificationService {
  static Future<ContactVerificationResult> verify(String phoneNumber) async {
    if (!EnhancedSocketService.isConnected()) {
      try {
        await EnhancedSocketService.connect(source: 'ContactVerification');
      } catch (_) {}
    }

    if (!EnhancedSocketService.isConnected()) {
      return const ContactVerificationResult(verified: false, exists: false);
    }

    final completer = Completer<ContactVerificationResult>();

    void handler(Map<String, dynamic> data) {
      if (completer.isCompleted) return;
      final userExists = data['exists'] as bool? ?? false;
      completer.complete(ContactVerificationResult(
        verified: true,
        exists: userExists,
        profileImageUrl: data['profile_image_url'] as String?,
        peerUserId: data['user_id'] as String?,
        contactName: data['name'] as String?,
      ));
    }

    SocketEventBus.instance.subscribe('phone_search_result', handler);

    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete(const ContactVerificationResult(verified: false, exists: false));
      }
    });

    EnhancedSocketService.searchPhone(phoneNumber);
    return completer.future;
  }
}
