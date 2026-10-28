import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'bindings.dart';
import 'player.dart';

/// Registers the Rust engine as `just_audio`'s platform backend.
class AmusicJustAudio extends JustAudioPlatform {
  AmusicJustAudio._();

  static final _players = <String, AmusicPlayer>{};
  static AmusicEq _eq = AmusicEq.off;

  /// The engine plays on every platform the app ships on.
  static bool get isSupported =>
      Platform.isMacOS ||
      Platform.isIOS ||
      Platform.isAndroid ||
      Platform.isWindows ||
      Platform.isLinux;

  /// Installs the backend if this platform uses it; returns whether it did.
  static bool ensureInitialized() {
    if (!isSupported) return false;
    JustAudioPlatform.instance = AmusicJustAudio._();
    return true;
  }

  /// Sets the equalizer for every player, current and future.
  static void setEq(AmusicEq eq) {
    _eq = eq;
    for (final player in _players.values) {
      player.applyEq(eq);
    }
  }

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    if (_players.containsKey(request.id)) {
      throw StateError('Player ${request.id} already exists');
    }
    final player = AmusicPlayer(request.id, AmusicNative.instance, _eq);
    _players[request.id] = player;
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    _players.remove(request.id)?.release();
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async {
    for (final player in _players.values) {
      player.release();
    }
    _players.clear();
    return DisposeAllPlayersResponse();
  }
}

/// Lets tests point the engine at a dylib and install the backend on any host.
@visibleForTesting
abstract final class AmusicJustAudioTestHook {
  static void useLibrary(String path) {
    AmusicNative.overrideLibrary(path);
  }

  static JustAudioPlatform platform() => AmusicJustAudio._();
}
