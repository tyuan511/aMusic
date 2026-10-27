import 'dart:async';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../core/config.dart';
import '../router.dart';
import '../services/app.dart';
import 'player/player_panel_controller.dart';

/// Desktop keyboard shortcuts, dispatched by the shell.
///
/// Returns `true` when the event was consumed. Text input is filtered out by
/// the caller, so plain letter keys are safe to bind here.
///
/// Bindings:
/// - Space / media play-pause: toggle playback
/// - Media next / previous, Shift + → / ←: next / previous track
/// - → / ←: seek ±5 s
/// - ↑ / ↓: volume ±5 %
/// - L / Q / C: open the player on lyrics / queue / comments (or switch
///   panel; the visible panel toggles back to the cover)
/// - F: toggle full screen
/// - M: mute / unmute
/// - Esc: close the player
bool handleAppShortcut(KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
  final player = app.player;
  final key = event.logicalKey;

  // Letter bindings never steal Cmd / Ctrl / Alt combinations (Cmd+Q...).
  final keyboard = HardwareKeyboard.instance;
  final plain =
      !keyboard.isControlPressed &&
      !keyboard.isMetaPressed &&
      !keyboard.isAltPressed;
  if (plain && event is KeyDownEvent) {
    final panel = _panelKeys[key];
    if (panel != null) {
      showPlayerPanel(panel);
      return true;
    }
    if (key == LogicalKeyboardKey.keyM) {
      player.toggleMute();
      return true;
    }
    if (key == LogicalKeyboardKey.keyF && Platforms.isDesktop) {
      unawaited(_toggleFullScreen());
      return true;
    }
    if (key == LogicalKeyboardKey.escape &&
        PlayerPanelController.instance.isOpen.value) {
      rootNavigatorKey.currentState?.maybePop();
      return true;
    }
  }

  if (key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.mediaPlayPause ||
      key == LogicalKeyboardKey.mediaPlay ||
      key == LogicalKeyboardKey.mediaPause) {
    if (event is KeyDownEvent) player.togglePlayPause();
    return true;
  }
  if (key == LogicalKeyboardKey.mediaTrackNext) {
    player.next();
    return true;
  }
  if (key == LogicalKeyboardKey.mediaTrackPrevious) {
    player.previous();
    return true;
  }
  if (event is KeyDownEvent && HardwareKeyboard.instance.isShiftPressed) {
    if (key == LogicalKeyboardKey.arrowRight) {
      player.next();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      player.previous();
      return true;
    }
  }
  if (key == LogicalKeyboardKey.arrowRight ||
      key == LogicalKeyboardKey.arrowLeft) {
    final delta = key == LogicalKeyboardKey.arrowRight ? 5 : -5;
    final clock = player.clock;
    final target = clock.now() + Duration(seconds: delta);
    final clamped = target < Duration.zero ? Duration.zero : target;
    clock.sync(clamped, running: player.playback.value.playing);
    player.seek(clamped);
    return true;
  }
  if (key == LogicalKeyboardKey.arrowUp ||
      key == LogicalKeyboardKey.arrowDown) {
    final delta = key == LogicalKeyboardKey.arrowUp ? 0.05 : -0.05;
    player.setVolume(player.volume.value + delta);
    return true;
  }
  return false;
}

final Map<LogicalKeyboardKey, PlayerPanel> _panelKeys = {
  LogicalKeyboardKey.keyL: PlayerPanel.lyrics,
  LogicalKeyboardKey.keyQ: PlayerPanel.queue,
  LogicalKeyboardKey.keyC: PlayerPanel.comments,
};

Future<void> _toggleFullScreen() async {
  try {
    final full = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!full);
  } on Object {
    // window_manager is not initialised (tests, mobile).
  }
}
