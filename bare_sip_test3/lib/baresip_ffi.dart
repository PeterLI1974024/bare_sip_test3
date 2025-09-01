import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

// 載入 libbaresip.so
final _lib = ffi.DynamicLibrary.open('libbaresip.so');

/// ======================
/// Core
/// ======================

// const char* baresip_version();
typedef _CStrFn = ffi.Pointer<Utf8> Function();
final _baresipVersion = _lib.lookupFunction<_CStrFn, _CStrFn>('baresip_version');

String bsVersion() => _baresipVersion().toDartString();

// int baresip_init();
typedef _CInit = ffi.Int32 Function();
typedef _DInit = int Function();
final _baresipInit = _lib.lookupFunction<_CInit, _DInit>('baresip_init');

int bsInit() => _baresipInit();

// void baresip_close();
typedef _CVoid = ffi.Void Function();
typedef _DVoid = void Function();
final _baresipClose = _lib.lookupFunction<_CVoid, _DVoid>('baresip_close');

void bsClose() => _baresipClose();

/// ======================
/// RE / Event loop
/// ======================

// int libre_init();
typedef _CLibreInit = ffi.Int32 Function();
typedef _DLibreInit = int Function();
final _libreInit = _lib.lookupFunction<_CLibreInit, _DLibreInit>('libre_init');

int reInit() => _libreInit();

/// ======================
/// UA (User Agent)
/// ======================

// int ua_init(const char* software, int aumode, int vumode, int dumode);
typedef _CUaInit = ffi.Int32 Function(ffi.Pointer<Utf8>, ffi.Uint8, ffi.Uint8, ffi.Uint8);
typedef _DUaInit = int Function(ffi.Pointer<Utf8>, int, int, int);
final _uaInit = _lib.lookupFunction<_CUaInit, _DUaInit>('ua_init');

int uaInit(String software, {int aumode = 1, int vumode = 1, int dumode = 1}) {
  final namePtr = software.toNativeUtf8();
  try {
    return _uaInit(namePtr, aumode, vumode, dumode);
  } finally {
    calloc.free(namePtr);
  }
}
