// ignore_for_file: library_private_types_in_public_api

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// One peaking filter, mirrors `AmusicBand` (12 bytes).
final class AmusicBand extends Struct {
  @Float()
  external double freq;
  @Float()
  external double q;
  @Float()
  external double gainDb;
}

/// What the engine reports; mirrors `AmusicStatus` (40 bytes).
final class AmusicStatus extends Struct {
  @Uint32()
  external int state;
  @Bool()
  external bool playing;
  @Double()
  external double position;
  @Double()
  external double duration;
  @Uint64()
  external int advanceSeq;
  @Uint64()
  external int loadSeq;
}

abstract final class EngineState {
  static const int idle = 0;
  static const int loading = 1;
  static const int ready = 2;
  static const int ended = 3;
  static const int error = 4;
}

typedef _NewC = Pointer<Void> Function();
typedef _FreeC = Void Function(Pointer<Void>);
typedef _Free = void Function(Pointer<Void>);
typedef _LoadC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Double);
typedef _Load = int Function(Pointer<Void>, Pointer<Utf8>, double);
typedef _SetNextC = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef _SetNext = void Function(Pointer<Void>, Pointer<Utf8>);
typedef _VoidC = Void Function(Pointer<Void>);
typedef _Void = void Function(Pointer<Void>);
typedef _SeekC = Void Function(Pointer<Void>, Double);
typedef _Seek = void Function(Pointer<Void>, double);
typedef _FloatC = Void Function(Pointer<Void>, Float);
typedef _FloatFn = void Function(Pointer<Void>, double);
typedef _SetEqC = Void Function(
  Pointer<Void>,
  Pointer<AmusicBand>,
  Size,
  Float,
  Bool,
  Uint32,
);
typedef _SetEq = void Function(
  Pointer<Void>,
  Pointer<AmusicBand>,
  int,
  double,
  bool,
  int,
);
typedef _StatusC = Void Function(Pointer<Void>, Pointer<AmusicStatus>);
typedef _Status = void Function(Pointer<Void>, Pointer<AmusicStatus>);
typedef _TakeErrorC = Size Function(Pointer<Void>, Pointer<Utf8>, Size);
typedef _TakeError = int Function(Pointer<Void>, Pointer<Utf8>, int);
typedef _RateC = Uint32 Function(Pointer<Void>);
typedef _Rate = int Function(Pointer<Void>);

/// Typed handles to the C ABI in `rust/include/amusic_engine.h`.
class AmusicNative {
  AmusicNative(DynamicLibrary lib)
    : create = lib.lookupFunction<_NewC, _NewC>('amusic_player_new'),
      free = lib.lookupFunction<_FreeC, _Free>('amusic_player_free'),
      load = lib.lookupFunction<_LoadC, _Load>('amusic_player_load'),
      setNext = lib.lookupFunction<_SetNextC, _SetNext>(
        'amusic_player_set_next',
      ),
      play = lib.lookupFunction<_VoidC, _Void>('amusic_player_play'),
      pause = lib.lookupFunction<_VoidC, _Void>('amusic_player_pause'),
      stop = lib.lookupFunction<_VoidC, _Void>('amusic_player_stop'),
      seek = lib.lookupFunction<_SeekC, _Seek>('amusic_player_seek'),
      setVolume = lib.lookupFunction<_FloatC, _FloatFn>(
        'amusic_player_set_volume',
      ),
      setSpeed = lib.lookupFunction<_SeekC, _Seek>('amusic_player_set_speed'),
      setEq = lib.lookupFunction<_SetEqC, _SetEq>('amusic_player_set_eq'),
      status = lib.lookupFunction<_StatusC, _Status>('amusic_player_status'),
      takeError = lib.lookupFunction<_TakeErrorC, _TakeError>(
        'amusic_player_take_error',
      ),
      sampleRate = lib.lookupFunction<_RateC, _Rate>(
        'amusic_player_sample_rate',
      );

  final Pointer<Void> Function() create;
  final _Free free;
  final _Load load;
  final _SetNext setNext;
  final _Void play;
  final _Void pause;
  final _Void stop;
  final _Seek seek;
  final _FloatFn setVolume;
  final _Seek setSpeed;
  final _SetEq setEq;
  final _Status status;
  final _TakeError takeError;
  final _Rate sampleRate;

  /// Where the library lives: linked into the app's `amusic_engine` framework
  /// on macOS. Tests (and tools) can point [AMUSIC_ENGINE_LIB] at a dylib.
  static DynamicLibrary openDefault() {
    final override = Platform.environment['AMUSIC_ENGINE_LIB'];
    if (override != null && override.isNotEmpty) {
      return DynamicLibrary.open(override);
    }
    if (Platform.isMacOS || Platform.isIOS) {
      return DynamicLibrary.open('amusic_engine.framework/amusic_engine');
    }
    if (Platform.isWindows) return DynamicLibrary.open('amusic_engine.dll');
    return DynamicLibrary.open('libamusic_engine.so');
  }

  static AmusicNative? _shared;

  /// Test hook: use the library at [path] instead of the bundled one.
  static void overrideLibrary(String path) {
    _shared = AmusicNative(DynamicLibrary.open(path));
  }

  /// The process wide instance.
  static AmusicNative get instance => _shared ??= AmusicNative(openDefault());

  /// Reads the engine's last error for [handle] (clears it).
  String errorOf(Pointer<Void> handle) {
    return using((arena) {
      const cap = 512;
      final buf = arena<Uint8>(cap).cast<Utf8>();
      final n = takeError(handle, buf, cap);
      return n == 0 ? '' : buf.toDartString(length: n);
    });
  }
}
