import 'package:flutter/foundation.dart';
import 'nearby_stub.dart'
    if (dart.library.android) 'nearby_android.dart';

/// Abstracted P2P permission check — no-op on non-Android platforms.
Future<void> requestNearbyPermissions() async {
  await NearbyPlatform.requestPermissions();
}
