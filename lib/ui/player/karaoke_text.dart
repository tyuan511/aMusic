import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../models/lyric.dart';

/// A word timed (YRC) line whose words fill from [dimColor] to [brightColor]
/// with a soft edged sweep as [clock] advances. Long held words lift a
/// little and glow.
///
/// The render object is a repaint boundary that listens to [clock] directly,
/// so playback only repaints this one line: no widget rebuilds, no layout.
///
/// [lite] drops the glow and the soft sweep edge, both offscreen layers per
/// frame, for weak GPUs.
class KaraokeText extends LeafRenderObjectWidget {
  const KaraokeText({
    super.key,
    required this.line,
    required this.style,
    required this.clock,
    this.textAlign = TextAlign.start,
    this.dimColor = const Color(0x80FFFFFF),
    this.brightColor = const Color(0xFFFFFFFF),
    this.maxLines,
    this.lite = false,
  });

  final LyricLine line;
  final TextStyle style;
  final ValueListenable<Duration> clock;
  final TextAlign textAlign;
  final Color dimColor;
  final Color brightColor;
  final int? maxLines;
  final bool lite;

  @override
  RenderKaraokeText createRenderObject(BuildContext context) =>
      RenderKaraokeText(
        line: line,
        style: style,
        clock: clock,
        textAlign: textAlign,
        dimColor: dimColor,
        brightColor: brightColor,
        maxLines: maxLines,
        lite: lite,
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderKaraokeText renderObject,
  ) {
    renderObject
      ..line = line
      ..style = style
      ..clock = clock
      ..textAlign = textAlign
      ..dimColor = dimColor
      ..brightColor = brightColor
      ..maxLines = maxLines
      ..lite = lite
      ..textScaler = MediaQuery.textScalerOf(context)
      ..textDirection = Directionality.of(context);
  }
}

/// Lift / glow envelope of a long held word, 0 - 1.
///
/// Rises over the first 400 ms of the word, holds, and settles over 300 ms
/// after it ends. Words shorter than [longWord] get none.
double wordEmphasis(LyricWord word, Duration position) {
  if (word.duration < longWord) return 0;
  final sinceStart = (position - word.start).inMilliseconds;
  if (sinceStart <= 0) return 0;
  final afterEnd = (position - word.end).inMilliseconds;
  if (afterEnd >= 300) return 0;
  final rise = math.sin(math.pi / 2 * math.min(1.0, sinceStart / 400));
  if (afterEnd <= 0) return rise;
  return rise * (1 - afterEnd / 300);
}

/// Words held at least this long lift and glow.
const Duration longWord = Duration(milliseconds: 1000);

class RenderKaraokeText extends RenderBox {
  RenderKaraokeText({
    required this._line,
    required this._style,
    required this._clock,
    required this._textAlign,
    required this._dimColor,
    required this._brightColor,
    required this._maxLines,
    required this._lite,
    required this._textScaler,
    required this._textDirection,
  });

  LyricLine _line;
  set line(LyricLine value) {
    if (identical(value, _line)) return;
    _line = value;
    _invalidate();
  }

  TextStyle _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _invalidate();
  }

  ValueListenable<Duration> _clock;
  set clock(ValueListenable<Duration> value) {
    if (identical(value, _clock)) return;
    if (attached) {
      _clock.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _clock = value;
    markNeedsPaint();
  }

  TextAlign _textAlign;
  set textAlign(TextAlign value) {
    if (value == _textAlign) return;
    _textAlign = value;
    _invalidate();
  }

  Color _dimColor;
  set dimColor(Color value) {
    if (value == _dimColor) return;
    _dimColor = value;
    _invalidate();
  }

  Color _brightColor;
  set brightColor(Color value) {
    if (value == _brightColor) return;
    _brightColor = value;
    _invalidate();
  }

  int? _maxLines;
  set maxLines(int? value) {
    if (value == _maxLines) return;
    _maxLines = value;
    _invalidate();
  }

  bool _lite;
  set lite(bool value) {
    if (value == _lite) return;
    _lite = value;
    markNeedsPaint();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _invalidate();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _invalidate();
  }

  TextPainter? _dim;
  TextPainter? _bright;

  /// Text range of every word inside the painted (trimmed) text.
  List<(int, int)> _ranges = const [];
  List<List<TextBox>> _boxes = const [];
  double? _laidOutWidth;

  void _invalidate() {
    _dim?.dispose();
    _bright?.dispose();
    _dim = null;
    _bright = null;
    _laidOutWidth = null;
    markNeedsLayout();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clock.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _clock.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _dim?.dispose();
    _bright?.dispose();
    super.dispose();
  }

  String get _text => _line.text;

  TextPainter _painter(Color color) => TextPainter(
    text: TextSpan(
      text: _text,
      style: _style.copyWith(color: color),
    ),
    textAlign: _textAlign,
    textDirection: _textDirection,
    textScaler: _textScaler,
    maxLines: _maxLines,
    ellipsis: _maxLines == null ? null : '…',
  );

  void _ensurePainters(double maxWidth) {
    if (_dim != null && _laidOutWidth == maxWidth) return;
    _dim ??= _painter(_dimColor);
    _bright ??= _painter(_brightColor);
    _dim!.layout(maxWidth: maxWidth);
    _bright!.layout(maxWidth: maxWidth);
    _laidOutWidth = maxWidth;
    _computeRanges();
  }

  void _computeRanges() {
    final joined = _line.words.map((word) => word.text).join();
    final lead = joined.length - joined.trimLeft().length;
    final length = _text.length;
    final ranges = <(int, int)>[];
    final boxes = <List<TextBox>>[];
    var cursor = 0;
    for (final word in _line.words) {
      final start = (cursor - lead).clamp(0, length);
      cursor += word.text.length;
      final end = (cursor - lead).clamp(0, length);
      ranges.add((start, end));
      boxes.add(
        end > start
            ? _dim!.getBoxesForSelection(
                TextSelection(baseOffset: start, extentOffset: end),
              )
            : const [],
      );
    }
    _ranges = ranges;
    _boxes = boxes;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    _ensurePainters(double.infinity);
    return _dim!.minIntrinsicWidth;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    _ensurePainters(double.infinity);
    return _dim!.maxIntrinsicWidth;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _ensurePainters(width);
    return _dim!.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final painter = _painter(_dimColor)..layout(maxWidth: constraints.maxWidth);
    final size = constraints.constrain(Size(painter.width, painter.height));
    painter.dispose();
    return size;
  }

  @override
  void performLayout() {
    _ensurePainters(constraints.maxWidth);
    size = constraints.constrain(Size(_dim!.width, _dim!.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final dim = _dim;
    final bright = _bright;
    if (dim == null || bright == null) return;
    final canvas = context.canvas;
    final position = _clock.value;
    final words = _line.words;
    final fontSize = _textScaler.scale(_style.fontSize ?? 16);
    final maxLift = fontSize * 0.07;
    final feather = _lite ? 0.0 : math.min(fontSize * 0.9, 22.0);

    // Words that need their own pass: lifted or mid-fill.
    final special = <int>[];
    final done = Path();
    var anyDone = false;
    for (var i = 0; i < words.length && i < _boxes.length; i++) {
      final word = words[i];
      final progress = word.progressAt(position);
      final emphasis = wordEmphasis(word, position);
      if (emphasis > 0 || (progress > 0 && progress < 1)) {
        special.add(i);
      } else if (progress >= 1) {
        for (final box in _boxes[i]) {
          done.addRect(box.toRect().shift(offset).inflate(0.5));
        }
        anyDone = true;
      }
    }

    // 1. Dim base, minus lifted words (they are redrawn shifted).
    final lifted = [
      for (final i in special)
        if (wordEmphasis(words[i], position) > 0) i,
    ];
    if (lifted.isEmpty) {
      dim.paint(canvas, offset);
    } else {
      canvas.save();
      final hole = Path()..fillType = PathFillType.evenOdd;
      hole.addRect((offset & size).inflate(fontSize));
      for (final i in lifted) {
        for (final box in _boxes[i]) {
          hole.addRect(box.toRect().shift(offset).inflate(0.5));
        }
      }
      canvas.clipPath(hole);
      dim.paint(canvas, offset);
      canvas.restore();
    }

    // 2. Finished words, one clip for all of them.
    if (anyDone) {
      canvas.save();
      canvas.clipPath(done);
      bright.paint(canvas, offset);
      canvas.restore();
    }

    // 3. The word being sung and the lifted ones.
    for (final i in special) {
      final word = words[i];
      final boxes = _boxes[i];
      if (boxes.isEmpty) continue;
      final emphasis = wordEmphasis(word, position);
      final lift = -maxLift * emphasis;
      final progress = word.progressAt(position);
      canvas.save();
      canvas.translate(0, lift);
      final bounds = boxes
          .map((box) => box.toRect().shift(offset))
          .reduce((a, b) => a.expandToInclude(b));

      if (emphasis > 0) {
        canvas.save();
        canvas.clipRect(bounds.inflate(0.5));
        dim.paint(canvas, offset);
        canvas.restore();
      }

      // Distance swept so far across the word's boxes (a word may wrap).
      final total = boxes.fold<double>(
        0,
        (sum, box) => sum + box.right - box.left,
      );
      final filled = total * progress;
      final glow = _lite ? 0.0 : emphasis * 0.55;
      if (glow > 0.01 && filled > 0) {
        final sigma = fontSize * 0.22;
        canvas.saveLayer(
          bounds.inflate(sigma * 3),
          Paint()
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma)
            ..color = Color.fromRGBO(255, 255, 255, glow),
        );
        _paintFill(canvas, bright, offset, boxes, filled, feather, sigma * 2);
        canvas.restore();
      }
      _paintFill(canvas, bright, offset, boxes, filled, feather, 0);
      canvas.restore();
    }
  }

  /// Paints [bright] over [boxes] up to [filled] logical pixels with a soft
  /// [feather] edge. [bleed] grows the clip vertically for the glow pass.
  void _paintFill(
    Canvas canvas,
    TextPainter bright,
    Offset offset,
    List<TextBox> boxes,
    double filled,
    double feather,
    double bleed,
  ) {
    var consumed = 0.0;
    for (final box in boxes) {
      final rect = box.toRect().shift(offset);
      final width = rect.width;
      final local = (filled - consumed).clamp(0.0, width);
      consumed += width;
      if (local <= 0) continue;
      final clip = Rect.fromLTRB(
        rect.left - bleed,
        rect.top - bleed,
        rect.right + bleed,
        rect.bottom + bleed,
      );
      final rtl = box.direction == TextDirection.rtl;
      if (local < width && feather <= 0) {
        // Hard edge: a clip instead of a gradient masked layer.
        canvas.save();
        canvas.clipRect(
          rtl
              ? Rect.fromLTRB(
                  rect.right - local,
                  clip.top,
                  clip.right,
                  clip.bottom,
                )
              : Rect.fromLTRB(
                  clip.left,
                  clip.top,
                  rect.left + local,
                  clip.bottom,
                ),
        );
        bright.paint(canvas, offset);
        canvas.restore();
        continue;
      }
      if (local >= width) {
        canvas.save();
        canvas.clipRect(clip);
        bright.paint(canvas, offset);
        canvas.restore();
        continue;
      }
      final edge = rtl ? rect.right - local : rect.left + local;
      final from = rtl ? edge + feather / 2 : edge - feather / 2;
      final to = rtl ? edge - feather / 2 : edge + feather / 2;
      canvas.saveLayer(clip, Paint());
      canvas.clipRect(clip);
      bright.paint(canvas, offset);
      canvas.drawRect(
        clip,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            Offset(from, rect.top),
            Offset(to, rect.top),
            const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('text', _text));
    properties.add(IntProperty('words', _ranges.length));
  }
}
