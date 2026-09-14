import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Native function signatures
typedef AudioAnalyzerInitC = Bool Function(Int32 sampleRate, Int32 bufferSize, Int32 numBands);
typedef AudioAnalyzerInitDart = bool Function(int sampleRate, int bufferSize, int numBands);

typedef AudioAnalyzerStartC = Bool Function();
typedef AudioAnalyzerStartDart = bool Function();

typedef AudioAnalyzerStopC = Void Function();
typedef AudioAnalyzerStopDart = void Function();

typedef AudioAnalyzerGetBandsC = Int32 Function(Pointer<Float> output, Int32 maxBands);
typedef AudioAnalyzerGetBandsDart = int Function(Pointer<Float> output, int maxBands);

typedef AudioAnalyzerGetAmplitudeC = Float Function();
typedef AudioAnalyzerGetAmplitudeDart = double Function();

typedef AudioAnalyzerGetFrameCountC = Int32 Function();
typedef AudioAnalyzerGetFrameCountDart = int Function();

typedef AudioAnalyzerDestroyC = Void Function();
typedef AudioAnalyzerDestroyDart = void Function();

/// Dart wrapper around the native C++ audio analyzer via FFI.
class AudioAnalyzer {
  static AudioAnalyzer? _instance;
  DynamicLibrary? _lib;
  bool _initialized = false;

  // Native function references
  AudioAnalyzerInitDart? _init;
  AudioAnalyzerStartDart? _start;
  AudioAnalyzerStopDart? _stop;
  AudioAnalyzerGetBandsDart? _getBands;
  AudioAnalyzerGetAmplitudeDart? _getAmplitude;
  AudioAnalyzerGetFrameCountDart? _getFrameCount;
  AudioAnalyzerDestroyDart? _destroy;

  AudioAnalyzer._();

  static AudioAnalyzer get instance {
    _instance ??= AudioAnalyzer._();
    return _instance!;
  }

  /// Load the native shared library.
  bool _loadLibrary() {
    if (_lib != null) return true;

    try {
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libaudio_analyzer.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process(); // statically linked
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('libaudio_analyzer.dylib');
      } else if (Platform.isLinux) {
        _lib = DynamicLibrary.open('libaudio_analyzer.so');
      } else if (Platform.isWindows) {
        _lib = DynamicLibrary.open('audio_analyzer.dll');
      }

      if (_lib == null) return false;

      _init = _lib!.lookupFunction<AudioAnalyzerInitC, AudioAnalyzerInitDart>('AudioAnalyzer_init');
      _start = _lib!.lookupFunction<AudioAnalyzerStartC, AudioAnalyzerStartDart>('AudioAnalyzer_start');
      _stop = _lib!.lookupFunction<AudioAnalyzerStopC, AudioAnalyzerStopDart>('AudioAnalyzer_stop');
      _getBands = _lib!.lookupFunction<AudioAnalyzerGetBandsC, AudioAnalyzerGetBandsDart>('AudioAnalyzer_getBands');
      _getAmplitude = _lib!.lookupFunction<AudioAnalyzerGetAmplitudeC, AudioAnalyzerGetAmplitudeDart>('AudioAnalyzer_getAmplitude');
      _getFrameCount = _lib!.lookupFunction<AudioAnalyzerGetFrameCountC, AudioAnalyzerGetFrameCountDart>('AudioAnalyzer_getFrameCount');
      _destroy = _lib!.lookupFunction<AudioAnalyzerDestroyC, AudioAnalyzerDestroyDart>('AudioAnalyzer_destroy');

      return true;
    } catch (e) {
      print('Failed to load audio analyzer library: $e');
      return false;
    }
  }

  /// Initialize with given sample rate and FFT size.
  bool initialize({int sampleRate = 44100, int bufferSize = 1024, int numBands = 36}) {
    if (_initialized) return true;
    if (!_loadLibrary()) return false;
    if (_init == null) return false;

    _initialized = _init!(sampleRate, bufferSize, numBands);
    return _initialized;
  }

  /// Start audio capture and analysis.
  bool start() {
    if (!_initialized || _start == null) return false;
    return _start!();
  }

  /// Stop audio capture.
  void stop() {
    if (!_initialized || _stop == null) return;
    _stop!();
  }

  /// Get frequency band magnitudes (0.0 - 1.0).
  List<double> getBands({int count = 36}) {
    if (!_initialized || _getBands == null) return List.filled(count, 0.0);

    final ptr = calloc<Float>(count);
    try {
      final written = _getBands!(ptr, count);
      final bands = List<double>.generate(written, (i) => ptr[i].toDouble());
      return bands;
    } finally {
      calloc.free(ptr);
    }
  }

  /// Get current RMS amplitude (0.0 - 1.0).
  double get amplitude {
    if (!_initialized || _getAmplitude == null) return 0.0;
    return _getAmplitude!();
  }

  /// Get the number of FFT frames processed.
  int get frameCount {
    if (!_initialized || _getFrameCount == null) return 0;
    return _getFrameCount!();
  }

  /// Release all native resources.
  void dispose() {
    if (!_initialized || _destroy == null) return;
    _destroy!();
    _initialized = false;
    _instance = null;
  }
}
