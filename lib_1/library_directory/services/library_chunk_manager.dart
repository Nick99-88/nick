import 'dart:math';

class LibraryChunkManager {
  static const int minSize = 256 * 1024;
  static const int maxSize = 5 * 1024 * 1024;

  int currentSize = 1024 * 1024;
  int _totalBytesUploaded = 0;

  int get totalBytesUploaded => _totalBytesUploaded;

  void restoreBytes(int bytes) {
    _totalBytesUploaded = bytes;
  }

  void updateBasedOnPerformance(Duration duration, int bytesUploaded) {
    _totalBytesUploaded += bytesUploaded;

    const targetDurationMs = 2000.0;

    if (duration.inMilliseconds < targetDurationMs * 0.5) {
      currentSize = (currentSize + (512 * 1024)).clamp(minSize, maxSize);
    } else if (duration.inMilliseconds > targetDurationMs * 2) {
      currentSize = (currentSize * 0.5).toInt().clamp(minSize, maxSize);
    }
  }

  void resetOnFailure() {
    currentSize = (currentSize * 0.5).toInt().clamp(minSize, maxSize);
  }
}
