import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

final _lib = ffi.DynamicLibrary.open('libbaresip_ffi.so');

// const char* bs_version();
typedef _CStrFn = ffi.Pointer<Utf8> Function();
final _bsVersion = _lib.lookupFunction<_CStrFn, _CStrFn>('bs_version');

// int bs_init();
typedef _CInit = ffi.Int32 Function();
typedef _DInit = int Function();
final _bsInit = _lib.lookupFunction<_CInit, _DInit>('bs_init');

// void bs_close();
typedef _CVoid = ffi.Void Function();
typedef _DVoid = void Function();
final _bsClose = _lib.lookupFunction<_CVoid, _DVoid>('bs_close');

// Dart 包裝
String bsVersion() => _bsVersion().toDartString();
int bsInit() => _bsInit();
void bsClose() => _bsClose();
