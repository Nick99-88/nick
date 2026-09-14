import 'dart:async';
import 'package:flutter/material.dart';
import '../services/call_signaling_service.dart';
import '../services/call_kit_service.dart';
import '../screens/unified_call_screen.dart';

/// Global call overlay — listens for incoming/outgoing calls and shows call UI.
class CallOverlayHost extends StatefulWidget {
  final Widget child;

  const CallOverlayHost({super.key, required this.child});

  @override
  State<CallOverlayHost> createState() => _CallOverlayHostState();
}

class _CallOverlayHostState extends State<CallOverlayHost> {
  StreamSubscription<CallSession>? _subscription;
  bool _callScreenOpen = false;

  @override
  void initState() {
    super.initState();
    CallSignalingService.instance.initialize();
    CallKitService.instance.initialize();
    _subscription = CallSignalingService.instance.callStateStream.listen(_onCallState);

    // Handle case where call was already established before we subscribed
    // (e.g., app launched from FCM notification)
    final activeCall = CallSignalingService.instance.activeCall;
    if (activeCall != null) {
      _onCallState(activeCall);
    }
  }

  void _onCallState(CallSession session) {
    if (!mounted) return;

    final shouldShow = session.state == CallState.ringing ||
        session.state == CallState.dialing ||
        session.state == CallState.connected;

    if (shouldShow && !_callScreenOpen) {
      _callScreenOpen = true;

      // Show snackbar for incoming calls
      if (session.state == CallState.ringing && session.direction == CallDirection.incoming) {
        final callType = session.type == CallType.video ? 'video' : 'voice';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                if (session.peerAvatar.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white24,
                      backgroundImage: NetworkImage(session.peerAvatar),
                    ),
                  ),
                Expanded(child: Text('Incoming $callType call from ${session.peerName}')),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => UnifiedCallScreen(session: session),
        ),
      ).then((_) {
        _callScreenOpen = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
