import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../data/net_image.dart';
import '../../theme/app_theme.dart';
import 'kit.dart';

/// Cover art.
///
/// Remote covers always request a resized variant through [NetImage] (NetEase
/// serves 1000px+ originals and lists scroll through hundreds of them).
/// Local covers (`file://...` or an absolute path, written by the local
/// library) are decoded from disk at the same target size.
///
/// While loading a shimmer is shown; the image fades in over 200 ms on its
/// first frame. Synchronously available (cached) images appear instantly.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    this.size = 200,
    this.width,
    this.height,
    this.radius = 8,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String? url;

  /// Target square size, used both for the CDN parameter and the decode size.
  final int size;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  /// Replaces the default shimmer / note placeholder.
  final Widget? placeholder;

  static const Duration _fadeIn = Duration(milliseconds: 200);

  /// Whether [url] points at a file on this device rather than the CDN.
  static bool isLocal(String url) =>
      url.startsWith('file://') ||
      url.startsWith('/') ||
      RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(url);

  /// Image provider for [url], or `null` when there is nothing to load.
  static ImageProvider<Object>? providerFor(String? url, {int size = 200}) {
    if (url == null || url.isEmpty) return null;
    if (isLocal(url)) {
      final path = url.startsWith('file://')
          ? Uri.parse(url).toFilePath()
          : url;
      return ResizeImage(
        FileImage(File(path)),
        width: size,
        policy: ResizeImagePolicy.fit,
      );
    }
    final resolved = sizedImage(url, size: size);
    return resolved.isEmpty ? null : NetImage(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final provider = providerFor(url, size: size);
    final fallback = placeholder ?? const _NotePlaceholder();
    final Widget image;
    if (provider == null) {
      image = SizedBox(width: width, height: height, child: fallback);
    } else {
      image = Image(
        image: provider,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return _FadeInFrame(
            loaded: frame != null,
            placeholder: placeholder ?? const _ShimmerPlaceholder(),
            child: child,
          );
        },
        errorBuilder: (context, error, _) =>
            SizedBox(width: width, height: height, child: fallback),
      );
    }
    if (radius <= 0) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

/// Fades the decoded image in over the shimmer, then drops the shimmer (and
/// its ticker) once the fade finished.
class _FadeInFrame extends StatefulWidget {
  const _FadeInFrame({
    required this.loaded,
    required this.placeholder,
    required this.child,
  });

  final bool loaded;
  final Widget placeholder;
  final Widget child;

  @override
  State<_FadeInFrame> createState() => _FadeInFrameState();
}

class _FadeInFrameState extends State<_FadeInFrame> {
  bool _settled = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (!_settled) Positioned.fill(child: widget.placeholder),
        AnimatedOpacity(
          opacity: widget.loaded ? 1 : 0,
          duration: CoverImage._fadeIn,
          curve: Curves.easeOut,
          onEnd: () {
            if (widget.loaded && mounted) setState(() => _settled = true);
          },
          child: widget.child,
        ),
      ],
    );
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  const _ShimmerPlaceholder();

  @override
  Widget build(BuildContext context) => const Skeleton(
    width: double.infinity,
    height: double.infinity,
    radius: 0,
  );
}

class _NotePlaceholder extends StatelessWidget {
  const _NotePlaceholder();

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.chip, Color.lerp(s.chip, s.lavender, 0.14)!],
        ),
      ),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide;
            final iconSize = side.isFinite
                ? (side * 0.36).clamp(14.0, 48.0)
                : 20.0;
            return Icon(
              Icons.music_note_rounded,
              size: iconSize,
              color: s.textTertiary.withValues(alpha: 0.6),
            );
          },
        ),
      ),
    );
  }
}
