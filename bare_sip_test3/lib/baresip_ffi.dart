import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

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

/// ======================
/// UA Allocate / Register
/// ======================

// ⚠️ v4.0.0: ua_alloc 需要 struct config*
// int ua_alloc(struct ua** uap, const char* aor, struct config* cfg);
typedef _CUaAlloc = ffi.Int32 Function(
  ffi.Pointer<ffi.Pointer<ffi.Void>>, // ua**
  ffi.Pointer<Utf8>, // aor
  ffi.Pointer<ffi.Void>, // config (可先傳 null)
);
typedef _DUaAlloc = int Function(
  ffi.Pointer<ffi.Pointer<ffi.Void>>,
  ffi.Pointer<Utf8>,
  ffi.Pointer<ffi.Void>,
);
final _uaAlloc = _lib.lookupFunction<_CUaAlloc, _DUaAlloc>('ua_alloc');

ffi.Pointer<ffi.Void>? createUa(String sipUri) {
  final uaPtr = calloc<ffi.Pointer<ffi.Void>>();
  final aor = sipUri.toNativeUtf8();
  final res = _uaAlloc(uaPtr, aor, ffi.nullptr);
  calloc.free(aor);
  if (res != 0) {
    calloc.free(uaPtr);
    return null;
  }
  return uaPtr.value;
}

// int ua_register(struct ua* ua);
typedef _CUaRegister = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef _DUaRegister = int Function(ffi.Pointer<ffi.Void>);
final _uaRegister = _lib.lookupFunction<_CUaRegister, _DUaRegister>('ua_register');
int uaRegister(ffi.Pointer<ffi.Void> ua) => _uaRegister(ua);

/// ======================
/// Call Control
/// ======================

// int ua_connect(struct ua* ua, struct call** callp,
//                const char* to_uri, const char* params, int vmode);
typedef _CUaConnect = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Pointer<ffi.Void>>,
  ffi.Pointer<Utf8>,
  ffi.Pointer<Utf8>,
  ffi.Int32,
);
typedef _DUaConnect = int Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Pointer<ffi.Void>>,
  ffi.Pointer<Utf8>,
  ffi.Pointer<Utf8>,
  int,
);
final _uaConnect = _lib.lookupFunction<_CUaConnect, _DUaConnect>('ua_connect');

int uaConnect(ffi.Pointer<ffi.Void> ua, String toUri) {
  final callPtr = calloc<ffi.Pointer<ffi.Void>>();
  final to = toUri.toNativeUtf8();
  final res = _uaConnect(ua, callPtr, to, ffi.nullptr, 0);
  calloc.free(to);
  return res;
}

// void ua_hangup(struct ua* ua, struct call* call, int err, const char* reason);
typedef _CUaHangup = ffi.Void Function(
  ffi.Pointer<ffi.Void>, // ua
  ffi.Pointer<ffi.Void>, // call
  ffi.Int32, // err
  ffi.Pointer<Utf8>, // reason
);
typedef _DUaHangup = void Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Void>,
  int,
  ffi.Pointer<Utf8>,
);
final _uaHangup = _lib.lookupFunction<_CUaHangup, _DUaHangup>('ua_hangup');

void uaHangup(ffi.Pointer<ffi.Void> ua, ffi.Pointer<ffi.Void> call, {int err = 0, String? reason}) {
  final r = reason?.toNativeUtf8() ?? ffi.nullptr;
  _uaHangup(ua, call, err, r);
  if (r != ffi.nullptr) calloc.free(r);
}

/// ======================
/// Events (bevent API)
/// ======================

// typedef void (bevent_h)(const struct bevent *ev, void *arg);
typedef _CBeventHandler = ffi.Void Function(
  ffi.Pointer<ffi.Void>, // bevent*
  ffi.Pointer<ffi.Void>, // arg
);
typedef _DBeventHandler = void Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Void>,
);

// void bevent_register_handler(bevent_h *h, void *arg);
typedef _CBeventRegister = ffi.Void Function(
  ffi.Pointer<ffi.NativeFunction<_CBeventHandler>>,
  ffi.Pointer<ffi.Void>,
);
typedef _DBeventRegister = void Function(
  ffi.Pointer<ffi.NativeFunction<_CBeventHandler>>,
  ffi.Pointer<ffi.Void>,
);
final _beventRegister = _lib.lookupFunction<_CBeventRegister, _DBeventRegister>('bevent_register_handler');

// Dart 封裝：註冊事件 callback
void beventRegister(ffi.Pointer<ffi.NativeFunction<_CBeventHandler>> cb, ffi.Pointer<ffi.Void> arg) {
  _beventRegister(cb, arg);
}
