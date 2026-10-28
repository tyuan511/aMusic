import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/prefs.dart';

/// Scales the whole UI by a factor without touching individual widgets.
///
/// The subtree is laid out at `size / scale` and painted scaled back up, so a
/// scale of 1.35 makes every widget 35 % larger, and 0.85
/// fits more on a small laptop. Car head units are left at 1: they are short
/// and wide, and zooming them shrinks the layout area so far that the player
/// falls back to its phone layout. Pointer events are transformed by the
/// framework, so hit testing stays exact.
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.settings, required this.child});

  final SettingsState settings;
  final Widget child;

  static const double min = 0.8;
  static const double max = 1.75;

  /// Scale picked when "auto" is on.
  static double autoScaleFor(MediaQueryData media) {
    if (Platforms.isDesktop) {
      // Grow gently on very large windows, never shrink below 1.
      final area = media.size.width * media.size.height;
      final ratio = math.sqrt(area / (1600 * 1000));
      return ratio.clamp(1.0, 1.25).toDouble();
    }
    return 1.0;
  }

  static double effective(SettingsState settings, MediaQueryData media) {
    final raw = settings.autoUiScale ? autoScaleFor(media) : settings.uiScale;
    return raw.clamp(min, max).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = effective(settings, media);
    if ((scale - 1).abs() < 0.01) return child;
    final logical = media.size / scale;
    return MediaQuery(
      data: media.copyWith(
        size: logical,
        devicePixelRatio: media.devicePixelRatio * scale,
        padding: media.padding / scale,
        viewPadding: media.viewPadding / scale,
        viewInsets: media.viewInsets / scale,
        systemGestureInsets: media.systemGestureInsets / scale,
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: logical.width,
          maxWidth: logical.width,
          minHeight: logical.height,
          maxHeight: logical.height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: child,
          ),
        ),
      ),
    );
  }
}
