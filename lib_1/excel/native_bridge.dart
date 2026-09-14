import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

final class NativeBridge {
  static NativeBridge? _instance;
  late final DynamicLibrary _lib;
  bool _initialized = false;

  NativeBridge._();

  static NativeBridge get instance {
    _instance ??= NativeBridge._();
    return _instance!;
  }

  bool get isAvailable => _initialized;

  void initialize() {
    if (_initialized) return;
    _lib = _loadLibrary();
    _initialized = true;
  }

  static DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libaudio_analyzer.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('audio_analyzer.dll');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libaudio_analyzer.so');
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libaudio_analyzer.dylib');
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  int init() {
    final func = _lib
        .lookupFunction<Int32 Function(), int Function()>('excel_engine_init');
    return func();
  }

  int add(int a, int b) {
    final func = _lib.lookupFunction<Int32 Function(Int32, Int32),
        int Function(int, int)>('excel_add');
    return func(a, b);
  }

  double calculate(double a, double b, int op) {
    final func = _lib.lookupFunction<Double Function(Double, Double, Int32),
        double Function(double, double, int)>('excel_calculate');
    return func(a, b, op);
  }

  String columnName(int index) {
    final func = _lib.lookupFunction<
        Void Function(Int32, Pointer<Utf8>, Int32),
        void Function(int, Pointer<Utf8>, int)>('excel_column_name');
    final out = calloc<Uint8>(32);
    final outPtr = out.cast<Utf8>();
    func(index, outPtr, 32);
    final result = outPtr.toDartString();
    calloc.free(out);
    return result;
  }

  List<String> batchColumnNames(int startIndex, int count) {
    final func = _lib.lookupFunction<
        Int32 Function(Int32, Int32, Pointer<Utf8>, Int32),
        int Function(int, int, Pointer<Utf8>, int)>('excel_batch_column_names');
    final bufferSize = count * 8;
    final out = calloc<Uint8>(bufferSize);
    final outPtr = out.cast<Utf8>();
    func(startIndex, count, outPtr, bufferSize);
    final result = outPtr.toDartString();
    calloc.free(out);
    if (result.isEmpty) return [];
    return result.split(',');
  }

  int compareValues(String a, String b) {
    final func = _lib.lookupFunction<
        Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
        int Function(Pointer<Utf8>, Pointer<Utf8>)>('excel_compare_values');
    final pa = a.toNativeUtf8();
    final pb = b.toNativeUtf8();
    final result = func(pa, pb);
    calloc.free(pa);
    calloc.free(pb);
    return result;
  }

}
