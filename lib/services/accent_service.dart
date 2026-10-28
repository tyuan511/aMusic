import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:amusic_engine/amusic_engine.dart';

import '../core/async_cache.dart';
import '../data/net_image.dart';

/// Accent colour plus a backdrop palette extracted from one cover.
typedef CoverColors = ({Color accent, List<Color> palette});

/// Extracts the dominant colour of the current album art.
///
/// The colour is published through a [ValueNotifier] instead of the theme so
/// that a track change repaints the player surfaces only, never the whole app.
/// [palette] holds 5 vivid-adjusted colours for the flowing backdrop.
class AccentService extends ValueNotifier<Color?> {
  AccentService() : super(null);

  /// 5 colours of the current cover, empty while unknown.
  final ValueNotifier<List<Color>> palette = ValueNotifier(const []);

  final AsyncCache<String, CoverColors> _cache = AsyncCache(
    ttl: const Duration(days: 1),
    maxEntries: 60,
  );

  String? _currentUrl;
  int _generation = 0;

  static const Color _fallback = Color(0xFFC8F04A);

  /// A small variant is enough for palette extraction and downloads far less.
  static String _thumbnail(String url) =>
      url.contains('?') ? url : '$url?param=120y120';

  Future<void> updateFor(String? picUrl) async {
    if (picUrl == null || picUrl.isEmpty) {
      _currentUrl = null;
      _generation++;
      value = null;
      palette.value = const [];
      return;
    }
    if (_currentUrl == picUrl) return;
    _currentUrl = picUrl;
    final generation = ++_generation;

    final cached = _cache.peek(picUrl);
    if (cached != null) {
      _publish(cached);
      return;
    }
    // Show nothing rather than the previous song's colour while loading.
    value = null;
    try {
      final colors = await _cache.get(picUrl, () => _extract(picUrl));
      if (generation == _generation) _publish(colors);
    } on Object {
      if (generation == _generation) {
        value = null;
        palette.value = const [];
      }
    }
  }

  void _publish(CoverColors colors) {
    value = colors.accent;
    palette.value = colors.palette;
  }

  /// Encoded bytes of the cover. Local music covers are `file://` URIs (or
  /// bare paths) written by the local library scanner; they must not go
  /// through the network pipeline.
  static Future<Uint8List> _bytesFor(String url) {
    final isFile =
        url.startsWith('file://') ||
        url.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url);
    if (!isFile) {
      return ImageByteCache.instance.load(
        _thumbnail(url),
        referer: 'https://music.163.com',
      );
    }
    final path = url.startsWith('file://') ? Uri.parse(url).toFilePath() : url;
    return File(path).readAsBytes();
  }

  Future<CoverColors> _extract(String picUrl) async {
    final swatches = await AmusicTools.coverPaletteAsync(
      await _bytesFor(picUrl),
    );
    if (swatches == null) throw StateError('undecodable cover: $picUrl');
    Color? slot(int argb) => argb == 0 ? null : Color(argb);
    // Vibrant first: it reads best as an accent on both light and dark surfaces.
    final accent =
        slot(swatches.vibrant) ??
        slot(swatches.lightVibrant) ??
        slot(swatches.darkVibrant) ??
        slot(swatches.dominant) ??
        _fallback;
    final candidates = [
      ?slot(swatches.dominant),
      ?slot(swatches.vibrant),
      ?slot(swatches.darkVibrant),
      ?slot(swatches.lightVibrant),
      ?slot(swatches.muted),
      ?slot(swatches.darkMuted),
      ...swatches.all.map(Color.new),
    ];
    return (accent: accent, palette: buildBackdropPalette(candidates, accent));
  }
}

/// Picks 5 distinct, vivid-adjusted colours from [candidates] (most important
/// first). Missing slots are filled by rotating the hue of [seed].
List<Color> buildBackdropPalette(List<Color> candidates, Color seed) {
  const count = 5;
  final picked = <HSLColor>[];
  for (final color in candidates) {
    final hsl = _vivid(HSLColor.fromColor(color));
    final distinct = picked.every((other) {
      final hue = (hsl.hue - other.hue).abs();
      final hueDistance = hue > 180 ? 360 - hue : hue;
      return hueDistance > 18 || (hsl.lightness - other.lightness).abs() > 0.14;
    });
    if (distinct) picked.add(hsl);
    if (picked.length == count) break;
  }
  final base = _vivid(HSLColor.fromColor(seed));
  var step = 0;
  while (picked.length < count) {
    step++;
    final shift = (step.isOdd ? 1 : -1) * 28.0 * ((step + 1) ~/ 2);
    picked.add(
      base
          .withHue((base.hue + shift) % 360)
          .withLightness(
            (base.lightness + (step.isOdd ? -0.08 : 0.06)).clamp(0.2, 0.6),
          ),
    );
  }
  return [for (final hsl in picked) hsl.toColor()];
}

/// Keeps a colour saturated enough to glow and dark/light enough to sit
/// behind white text.
HSLColor _vivid(HSLColor hsl) {
  final saturation = hsl.saturation < 0.08
      ? hsl.saturation
      : (hsl.saturation * 1.25 + 0.1).clamp(0.45, 0.92);
  return hsl
      .withSaturation(saturation)
      .withLightness(hsl.lightness.clamp(0.22, 0.58));
}
