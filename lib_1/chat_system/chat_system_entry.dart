import 'package:flutter/material.dart';
import 'package:starlight_flutter/core/theme.dart';
import 'package:starlight_flutter/core/storage.dart';
import 'package:starlight_flutter/chat_system/screens/whatsapp_phone_verification_screen.dart';
import 'package:starlight_flutter/chat_system/screens/whatsapp_chat_list_screen.dart';
import 'package:starlight_flutter/chat_system/services/chat_system_initializer.dart';
import 'package:starlight_flutter/chat_system/widgets/call_overlay_host.dart';

class WhatsAppChatEntry extends StatefulWidget {
  const WhatsAppChatEntry({super.key});

  @override
  State<WhatsAppChatEntry> createState() => _WhatsAppChatEntryState();
}

class _WhatsAppChatEntryState extends State<WhatsAppChatEntry> {
  bool _hasPhone = false;
  bool _isChecking = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _checkPhone();
  }

  Future<void> _checkPhone() async {
    try {
      final phone = await StarlightStorage.getUserPhoneNumber();
      final verifiedPhone = await StarlightStorage.getVerifiedPhone();
      final hasPhone = (phone != null && phone.isNotEmpty) ||
          (verifiedPhone != null && verifiedPhone.isNotEmpty);

      if (mounted) {
        setState(() {
          _hasPhone = hasPhone;
          _isChecking = false;
          _initError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPhone = false;
          _isChecking = false;
          _initError = null;
        });
      }
    }
  }

  void _onVerified() {
    setState(() => _isChecking = true);
    _checkPhone().then((_) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPhone) {
      return WhatsAppPhoneVerificationScreen(onVerified: _onVerified);
    }

    return FutureBuilder<bool>(
      future: ChatSystemInitializer.instance.isReady(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: StarlightTheme.primaryBlue,
              title: const Text('Starlight Chats', style: TextStyle(color: Colors.white)),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return const CallOverlayHost(child: WhatsAppChatListScreen());
        }

        final error = ChatSystemInitializer.instance.errorMessage ?? _initError ?? 'Unable to initialize chat system';
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: StarlightTheme.primaryBlue,
            title: const Text('Starlight Chats', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 72, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Chat Initialization Failed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
