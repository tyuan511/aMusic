import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../models/lyric.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../widgets/kit.dart';
import 'karaoke_text.dart';
import 'lyrics_motion.dart';

/// How the viewport is used.
enum LyricsLayout {
  /// The whole panel: focus at ~35 % height, scrollable, selectable.
  full,

  /// Three centred lines under the cover; tap opens the full panel.
  preview,
}

/// Appearance knobs read from settings (rebuilds only when one changes).
@immutable
class _LineConfig {
  const _LineConfig({
    required this.fontSize,
    required this.weight,
    required this.translation,
    required this.romaji,
    required this.blur,
  });

  final double fontSize;
  final FontWeight weight;
  final bool translation;
  final bool romaji;
  final bool blur;

  @override
  bool operator ==(Object other) =>
      other is _LineConfig &&
      other.fontSize == fontSize &&
      other.weight == weight &&
      other.translation == translation &&
      other.romaji == romaji &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(fontSize, weight, translation, romaji, blur);
}

/// Spring animated lyric list.
///
/// One ticker drives everything: it reads [PlaybackClock], moves the focus
/// when the line changes (a `setState` that rebuilds two line widgets) and
/// advances the per-line springs (paint only). The active YRC line repaints
/// itself from a clock notifier; other lines never repaint while static.
///
/// The ticker only runs while something moves: springs, a fling, or an active
/// line that follows the clock (word timed text, interlude dots). Between the
/// lines of a plain LRC lyric it sleeps until a timer wakes it for the next
/// line, so a still screen produces no frames at all.
class LyricsViewport extends StatefulWidget {
  const LyricsViewport({
    super.key,
    required this.lyric,
    this.layout = LyricsLayout.full,
    this.onTap,
    this.textAlign = TextAlign.start,
    this.padding = const EdgeInsets.symmetric(horizontal: 28),
    this.onSelectionChanged,
    this.selectionToolbarBuilder,
  });

  final Lyric lyric;
  final LyricsLayout layout;

  /// Preview only: tap anywhere.
  final VoidCallback? onTap;
  final TextAlign textAlign;
  final EdgeInsets padding;

  /// Full only: the selected line indices whenever they change.
  final ValueChanged<List<int>>? onSelectionChanged;

  /// Full only: builds the toolbar shown while lines are selected.
  final Widget Function(
    BuildContext context,
    List<int> selected,
    VoidCallback clear,
  )?
  selectionToolbarBuilder;

  @override
  State<LyricsViewport> createState() => _LyricsViewportState();
}

class _LyricsViewportState extends State<LyricsViewport>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final Stopwatch _time = Stopwatch()..start();
  final ValueNotifier<Duration> _karaokeClock = ValueNotifier(Duration.zero);
  late _ViewportModel _model = _ViewportModel(anchor: _anchor)
    ..onRetarget = _wake;

  int _active = -1;
  late _LineConfig _config = _readConfig();

  // Manual scrolling.
  bool _manual = false;
  Simulation? _fling;
  double _flingStart = 0;
  Timer? _resumeTimer;

  /// Wakes the idle ticker when the next line is due.
  Timer? _lineTimer;

  final Set<int> _selected = {};
  List<Widget?> _cache = const [];

  bool get _full => widget.layout == LyricsLayout.full;
  double get _anchor => _full ? 0.35 : 0.5;
  double get _now => _time.elapsedMicroseconds / 1e6;

  /// The focus moves a touch early so the spring lands on time.
  static const Duration _lead = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    app.settings.addListener(_onSettings);
    app.player.playback.addListener(_onPlayback);
    app.player.position.addListener(_onPosition);
    _resetForLyric();
    _ticker.start();
  }

  @override
  void didUpdateWidget(LyricsViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lyric, widget.lyric) ||
        oldWidget.layout != widget.layout) {
      _model = _ViewportModel(anchor: _anchor)..onRetarget = _wake;
      _selected.clear();
      _manual = false;
      _fling = null;
      _resetForLyric();
      _wake();
    }
    if (oldWidget.textAlign != widget.textAlign) _invalidateAll();
  }

  @override
  void dispose() {
    app.settings.removeListener(_onSettings);
    app.player.playback.removeListener(_onPlayback);
    app.player.position.removeListener(_onPosition);
    _resumeTimer?.cancel();
    _lineTimer?.cancel();
    _ticker.dispose();
    _karaokeClock.dispose();
    super.dispose();
  }

  _LineConfig _readConfig() {
    final s = app.settings.value;
    final preview = !_full;
    return _LineConfig(
      fontSize: preview ? 16.5 : s.lyricFontSize.clamp(16.0, 44.0),
      weight: _weight(s.lyricFontWeight),
      translation: !preview && s.showTranslation,
      romaji: !preview && s.showRomaji,
      blur: !preview && s.useLyricBlur,
    );
  }

  static FontWeight _weight(int value) => switch (value) {
    <= 400 => FontWeight.w400,
    <= 500 => FontWeight.w500,
    <= 600 => FontWeight.w600,
    _ => FontWeight.w700,
  };

  void _onSettings() {
    final next = _readConfig();
    if (next == _config) return;
    setState(() {
      _config = next;
      _invalidateAll();
    });
  }

  void _invalidateAll() =>
      _cache = List.filled(widget.lyric.lines.length + 1, null);

  void _resetForLyric() {
    _invalidateAll();
    final position = app.player.clock.now();
    _active = widget.lyric.lineIndexAt(position + _lead);
    _model.setFocus(math.max(0, _active), time: _now, animate: false);
    _karaokeClock.value = position;
  }

  void _onPlayback() => _wake();

  /// Seeks (and timer drift) while the ticker is idle: sync from the 5 Hz
  /// stream, but only wake when that changes what is shown.
  void _onPosition() {
    if (_ticker.isActive) return;
    final position = app.player.clock.now();
    if (widget.lyric.lineIndexAt(position + _lead) != _active ||
        _activeFollowsClock) {
      _wake();
    }
  }

  void _wake() {
    _lineTimer?.cancel();
    _lineTimer = null;
    if (!_ticker.isActive && mounted) _ticker.start();
  }

  /// The active line repaints from the clock while it plays.
  bool get _activeFollowsClock {
    final lines = widget.lyric.lines;
    if (_active < 0 || _active >= lines.length) return false;
    final line = lines[_active];
    return line.isEmpty || line.hasWords;
  }

  /// Puts the ticker to sleep until the line after [_active] is due.
  void _sleepUntilNextLine(Duration position) {
    _lineTimer?.cancel();
    _lineTimer = null;
    final lines = widget.lyric.lines;
    final next = _active + 1;
    if (next >= lines.length) return;
    final speed = math.max(app.player.clock.speed, 0.1);
    final wait = (lines[next].time - _lead - position) * (1 / speed);
    // The floor keeps an out of order line from waking it every frame.
    const floor = Duration(milliseconds: 20);
    _lineTimer = Timer(wait < floor ? floor : wait, _wake);
  }

  void _onTick(Duration _) {
    final lyric = widget.lyric;
    final position = app.player.clock.now();
    _karaokeClock.value = position;
    final index = lyric.lineIndexAt(position + _lead);
    if (index != _active) _setActive(index);

    final now = _now;
    var moving = false;
    final fling = _fling;
    if (fling != null) {
      final t = now - _flingStart;
      _setManualOffset(fling.x(t));
      if (fling.isDone(t)) {
        _fling = null;
      } else {
        moving = true;
      }
    }
    _model.time = now;
    if (!_model.settled(now)) {
      moving = true;
      _model.notify();
    }
    final playing = app.player.playback.value.playing;
    if (moving || (playing && _activeFollowsClock)) return;
    _ticker.stop();
    if (playing) _sleepUntilNextLine(position);
  }

  void _setActive(int index) {
    final previous = _active;
    _active = index;
    if (previous >= 0 && previous < _cache.length) _cache[previous] = null;
    if (index >= 0 && index < _cache.length) _cache[index] = null;
    if (!_manual && _selected.isEmpty) {
      _model.setFocus(math.max(0, index), time: _now);
    } else {
      _model.setEmphasisFocus(math.max(0, index), time: _now);
    }
    setState(() {});
  }

  // ------------------------------------------------------------- scrolling

  void _beginManual() {
    if (!_full) return;
    _resumeTimer?.cancel();
    _fling = null;
    if (!_manual) {
      _manual = true;
      _model.beginManual(_now);
      setState(() {});
    }
  }

  void _setManualOffset(double value) => _model.manualOffset = value;

  void _onDragUpdate(double delta) {
    _beginManual();
    _setManualOffset(_model.manualOffset - delta);
    _wake();
  }

  void _onDragEnd(double velocity) {
    if (!_manual) return;
    _fling = FrictionSimulation(0.135, _model.manualOffset, -velocity);
    _flingStart = _now;
    _wake();
    _scheduleResume();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_full) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final scroll = event as PointerScrollEvent;
      _onDragUpdate(-scroll.scrollDelta.dy);
      _scheduleResume();
    });
  }

  void _scheduleResume() {
    if (_selected.isNotEmpty) return;
    _resumeTimer?.cancel();
    final seconds = app.settings.value.lyricResumeSeconds.clamp(1.0, 10.0);
    _resumeTimer = Timer(
      Duration(milliseconds: (seconds * 1000).round()),
      _resume,
    );
  }

  void _resume() {
    if (!mounted || !_manual) return;
    _resumeTimer?.cancel();
    _fling = null;
    _manual = false;
    _model.endManual(math.max(0, _active), _now);
    setState(() {});
    _wake();
  }

  // -------------------------------------------------------------- selection

  void _onLineTap(int index) {
    if (_selected.isNotEmpty) {
      _toggleSelected(index);
      return;
    }
    final line = widget.lyric.lines[index];
    app.player.seek(line.time);
    if (_manual) _resume();
  }

  void _onLineLongPress(int index) {
    if (!_full) return;
    HapticFeedback.selectionClick();
    _toggleSelected(index);
  }

  void _toggleSelected(int index) {
    setState(() {
      if (!_selected.remove(index)) _selected.add(index);
      _cache[index] = null;
    });
    if (_selected.isEmpty) {
      _scheduleResume();
    } else {
      _resumeTimer?.cancel();
      _beginManual();
    }
    widget.onSelectionChanged?.call(_sortedSelection);
  }

  List<int> get _sortedSelection => _selected.toList()..sort();

  void _clearSelection() {
    final indices = [..._selected];
    setState(() {
      _selected.clear();
      for (final i in indices) {
        if (i < _cache.length) _cache[i] = null;
      }
    });
    widget.onSelectionChanged?.call(const []);
    _resume();
  }

  // ------------------------------------------------------------------ build

  Widget _line(int index) {
    final cached = _cache[index];
    if (cached != null) return cached;
    final line = widget.lyric.lines[index];
    final built = _LyricLineView(
      key: ValueKey(index),
      line: line,
      active: index == _active,
      selected: _selected.contains(index),
      config: _config,
      textAlign: widget.textAlign,
      preview: !_full,
      clock: _karaokeClock,
      nextTime: index + 1 < widget.lyric.lines.length
          ? widget.lyric.lines[index + 1].time
          : null,
      onTap: _full ? () => _onLineTap(index) : null,
      onLongPress: _full ? () => _onLineLongPress(index) : null,
    );
    _cache[index] = built;
    return built;
  }

  @override
  Widget build(BuildContext context) {
    final lyric = widget.lyric;
    if (_cache.length != lyric.lines.length + 1) _invalidateAll();
    final column = _LyricColumn(
      model: _model,
      textAlign: widget.textAlign,
      blur: _config.blur && !_manual,
      padding: widget.padding,
      footer: false,
      gap: _full ? _config.fontSize * 0.9 : 10,
      edgeFade: _full ? const (0.12, 0.82) : const (0.22, 0.78),
      children: [
        for (var i = 0; i < lyric.lines.length; i++) _line(i),
      ],
    );
    if (!_full) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: column,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _beginManual(),
              onVerticalDragUpdate: (details) =>
                  _onDragUpdate(details.delta.dy),
              onVerticalDragEnd: (details) =>
                  _onDragEnd(details.velocity.pixelsPerSecond.dy),
              child: column,
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: _FadeScale(
            visible: _manual && _selected.isEmpty,
            child: _ResumeChip(onTap: _resume),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: _FadeScale(
            visible: _selected.isNotEmpty,
            child: _selected.isEmpty || widget.selectionToolbarBuilder == null
                ? const SizedBox.shrink()
                : widget.selectionToolbarBuilder!(
                    context,
                    _sortedSelection,
                    _clearSelection,
                  ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- model

/// Layout + spring state shared by the state (ticks, gestures) and the render
/// object (layout, paint).
class _ViewportModel extends ChangeNotifier {
  _ViewportModel({required this.anchor});

  final double anchor;

  List<double> _tops = const [];
  List<double> _heights = const [];
  double _viewport = 0;
  List<LineSpring> _springs = const [];

  int _focus = 0;
  int _emphasisFrom = 0;
  int _emphasisTo = 0;
  double _emphasisStart = -10;
  static const double _emphasisSeconds = 0.36;

  bool _manual = false;
  double _manualOffset = 0;

  double time = 0;

  /// Called when a relayout starts springs moving while the ticker may be
  /// asleep (font size, translation toggled mid line).
  VoidCallback? onRetarget;

  int get count => _tops.length;

  void notify() => notifyListeners();

  /// Scroll offset that puts line [index] on the anchor.
  double _targetFor(int index) {
    if (_tops.isEmpty) return 0;
    final i = index.clamp(0, _tops.length - 1);
    return _tops[i] + _heights[i] / 2 - _viewport * anchor;
  }

  /// Scroll offset of line [index] right now.
  double offsetOf(int index, double now) {
    if (_manual) return _manualOffset;
    if (index < 0 || index >= _springs.length) return _targetFor(_focus);
    return _springs[index].valueAt(now);
  }

  double get manualOffset => _manualOffset;
  set manualOffset(double value) {
    if (_tops.isEmpty) return;
    final low = _targetFor(0) - _viewport * 0.2;
    final high = _targetFor(_tops.length - 1) + _viewport * 0.2;
    _manualOffset = value.clamp(math.min(low, high), math.max(low, high));
    notifyListeners();
  }

  void didLayout(List<double> tops, List<double> heights, double viewport) {
    final structural =
        tops.length != _tops.length || (viewport - _viewport).abs() > 0.5;
    _tops = tops;
    _heights = heights;
    _viewport = viewport;
    final target = _targetFor(_focus);
    if (structural || _springs.length != tops.length) {
      _springs = [for (var i = 0; i < tops.length; i++) LineSpring(target)];
      return;
    }
    // Heights changed (font size, translation): glide to the new place.
    var moved = false;
    for (final spring in _springs) {
      if ((spring.target - target).abs() > 0.5) {
        spring.retarget(target, time: time);
        moved = true;
      }
    }
    if (moved) onRetarget?.call();
  }

  void setFocus(int index, {required double time, bool animate = true}) {
    if (index == _focus && _springs.isNotEmpty && animate) return;
    setEmphasisFocus(index, time: time, animate: animate);
    _focus = index;
    if (_springs.isEmpty) return;
    final target = _targetFor(index);
    for (var i = 0; i < _springs.length; i++) {
      if (!animate) {
        _springs[i].jumpTo(target);
        continue;
      }
      final delay = LyricMotion.staggerDelay(i, index).inMicroseconds / 1e6;
      _springs[i].retarget(target, time: time, delay: delay);
    }
    notifyListeners();
  }

  /// Moves only the highlight (scale / opacity / blur), not the scroll.
  void setEmphasisFocus(
    int index, {
    required double time,
    bool animate = true,
  }) {
    if (index == _emphasisTo) return;
    _emphasisFrom = animate ? _emphasisTo : index;
    _emphasisTo = index;
    _emphasisStart = animate ? time : -10;
    notifyListeners();
  }

  void beginManual(double now) {
    _manualOffset = _springs.isEmpty
        ? _targetFor(_focus)
        : _springs[math.min(_focus, _springs.length - 1)].valueAt(now);
    _manual = true;
    notifyListeners();
  }

  void endManual(int focus, double now) {
    _manual = false;
    _focus = focus;
    setEmphasisFocus(focus, time: now);
    final target = _targetFor(focus);
    for (var i = 0; i < _springs.length; i++) {
      _springs[i].jumpTo(_manualOffset);
      final delay = LyricMotion.staggerDelay(i, focus).inMicroseconds / 1e6;
      _springs[i].retarget(target, time: now, delay: delay);
    }
    notifyListeners();
  }

  /// 0 - 1 progress of the emphasis transition.
  double _emphasisT(double now) {
    final t = (now - _emphasisStart) / _emphasisSeconds;
    return Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
  }

  double scaleOf(int index, double now) {
    final t = _emphasisT(now);
    return ui.lerpDouble(
      LyricMotion.scaleFor(index - _emphasisFrom),
      LyricMotion.scaleFor(index - _emphasisTo),
      t,
    )!;
  }

  double opacityOf(int index, double now) {
    final t = _emphasisT(now);
    return ui.lerpDouble(
      LyricMotion.opacityFor(index - _emphasisFrom),
      LyricMotion.opacityFor(index - _emphasisTo),
      t,
    )!;
  }

  int blurLevelOf(int index, double now) {
    final t = _emphasisT(now);
    final from = LyricMotion.blurLevelFor(index - _emphasisFrom);
    final to = LyricMotion.blurLevelFor(index - _emphasisTo);
    return (from + (to - from) * t).round();
  }

  bool settled(double now) {
    if (_emphasisT(now) < 1) return false;
    if (_manual) return true;
    for (final spring in _springs) {
      if (!spring.isDoneAt(now)) return false;
    }
    return true;
  }
}

// ----------------------------------------------------------- render column

class _LyricColumn extends MultiChildRenderObjectWidget {
  const _LyricColumn({
    required this.model,
    required this.textAlign,
    required this.blur,
    required this.padding,
    required this.footer,
    required this.gap,
    required this.edgeFade,
    required super.children,
  });

  final _ViewportModel model;
  final TextAlign textAlign;
  final bool blur;
  final EdgeInsets padding;
  final bool footer;
  final double gap;

  /// Fractions of the height where lines finish fading in at the top and
  /// start fading out at the bottom.
  final (double, double) edgeFade;

  @override
  _RenderLyricColumn createRenderObject(BuildContext context) =>
      _RenderLyricColumn(
        model: model,
        textAlign: textAlign,
        blur: blur,
        padding: padding,
        footer: footer,
        gap: gap,
        edgeFade: edgeFade,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLyricColumn renderObject,
  ) {
    renderObject
      ..model = model
      ..textAlign = textAlign
      ..blur = blur
      ..padding = padding
      ..footer = footer
      ..gap = gap
      ..edgeFade = edgeFade;
  }
}

class _LineParentData extends ContainerBoxParentData<RenderBox> {
  double top = 0;
}

class _RenderLyricColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LineParentData> {
  _RenderLyricColumn({
    required this._model,
    required this._textAlign,
    required this._blur,
    required this._padding,
    required this._footer,
    required this._gap,
    required this._edgeFade,
  });

  _ViewportModel _model;
  set model(_ViewportModel value) {
    if (identical(value, _model)) return;
    if (attached) {
      _model.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _model = value;
    markNeedsLayout();
  }

  TextAlign _textAlign;
  set textAlign(TextAlign value) {
    if (value == _textAlign) return;
    _textAlign = value;
    markNeedsLayout();
  }

  bool _blur;
  set blur(bool value) {
    if (value == _blur) return;
    _blur = value;
    markNeedsPaint();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  bool _footer;
  set footer(bool value) {
    if (value == _footer) return;
    _footer = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  (double, double) _edgeFade;
  set edgeFade((double, double) value) {
    if (value == _edgeFade) return;
    _edgeFade = value;
    markNeedsPaint();
  }

  /// Top / bottom fade of a line centred at [y]. Folded into the line's own
  /// opacity, so the edges cost no full size mask layer every frame.
  double _edgeOpacity(double y) {
    final height = size.height;
    if (height <= 0) return 1;
    final t = y / height;
    final (top, bottom) = _edgeFade;
    if (t <= 0 || t >= 1) return 0;
    if (t < top) return t / top;
    if (t > bottom) return (1 - t) / (1 - bottom);
    return 1;
  }

  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  /// Layer handles reused across frames: opacity per (blur level, alpha)
  /// group, blur per level.
  final Map<int, LayerHandle<OpacityLayer>> _opacityLayers = {};
  final Map<int, LayerHandle<ImageFilterLayer>> _blurLayers = {};

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LineParentData) {
      child.parentData = _LineParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _model.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _model.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    for (final handle in _opacityLayers.values) {
      handle.layer = null;
    }
    for (final handle in _blurLayers.values) {
      handle.layer = null;
    }
    super.dispose();
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : 400.0;
    size = Size(width, height);
    final inner = math.max(0.0, width - _padding.horizontal);
    final tops = <double>[];
    final heights = <double>[];
    var y = 0.0;
    var child = firstChild;
    var index = 0;
    final lines = childCount - (_footer ? 1 : 0);
    while (child != null) {
      child.layout(BoxConstraints(maxWidth: inner), parentUsesSize: true);
      final data = child.parentData! as _LineParentData;
      final dx = switch (_textAlign) {
        TextAlign.center => (inner - child.size.width) / 2,
        TextAlign.right || TextAlign.end => inner - child.size.width,
        _ => 0.0,
      };
      if (index > 0) y += index == lines ? _gap * 1.6 : _gap;
      data.top = y;
      data.offset = Offset(_padding.left + dx, y);
      if (index < lines) {
        tops.add(y);
        heights.add(child.size.height);
      }
      y += child.size.height;
      child = data.nextSibling;
      index++;
    }
    _model.didLayout(tops, heights, height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Lines slide past the edges; the fade used to clip them as a side effect.
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintLines,
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintLines(PaintingContext context, Offset offset) {
    final now = _model.time;
    final lines = _model.count;
    // Children grouped by blur level, then by opacity. Each blur level is one
    // offscreen blur pass for all of its lines, whatever their opacity, so at
    // most [LyricMotion.blurLevels] of them run per frame.
    final groups = <int, Map<int, List<(RenderBox, int)>>>{};
    var child = firstChild;
    var index = 0;
    while (child != null) {
      final data = child.parentData! as _LineParentData;
      final lineIndex = math.max(0, math.min(index, lines - 1));
      final y = data.top - _model.offsetOf(lineIndex, now);
      data.offset = Offset(data.offset.dx, y);
      final visible = y + child.size.height > -40 && y < size.height + 40;
      final edge = visible ? _edgeOpacity(y + child.size.height / 2) : 0.0;
      if (edge > 0) {
        final level = _blur ? _model.blurLevelOf(lineIndex, now) : 0;
        final opacity = index >= lines
            ? 140 / 255
            : _model.opacityOf(lineIndex, now);
        // 16 steps: every distinct value is its own layer, so mid animation
        // fine steps would mean a layer per line.
        final alpha = ((opacity * edge * 255 / 16).round() * 16).clamp(0, 255);
        if (alpha > 0) {
          ((groups[level] ??= {})[alpha] ??= []).add((child, index));
        }
      }
      child = data.nextSibling;
      index++;
    }

    final usedOpacity = <int>{};
    final usedBlur = <int>{};
    for (final MapEntry(key: level, value: byAlpha) in groups.entries) {
      void paintLevel(PaintingContext context, Offset origin) {
        for (final MapEntry(key: alpha, value: members) in byAlpha.entries) {
          final key = level * 1000 + alpha;
          usedOpacity.add(key);
          final handle = _opacityLayers[key] ??= LayerHandle<OpacityLayer>();
          handle.layer = context.pushOpacity(origin, alpha, (context, origin) {
            for (final (child, index) in members) {
              _paintLine(context, origin, child, index, now);
            }
          }, oldLayer: handle.layer);
        }
      }

      if (level == 0) {
        paintLevel(context, offset);
        continue;
      }
      usedBlur.add(level);
      final sigma = LyricMotion.sigmaForLevel(level);
      final handle = _blurLayers[level] ??= LayerHandle<ImageFilterLayer>();
      final layer = handle.layer ??= ImageFilterLayer();
      layer.imageFilter = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.decal,
      );
      context.pushLayer(layer, paintLevel, offset);
    }
    _opacityLayers.removeWhere((key, handle) {
      if (usedOpacity.contains(key)) return false;
      handle.layer = null;
      return true;
    });
    _blurLayers.removeWhere((key, handle) {
      if (usedBlur.contains(key)) return false;
      handle.layer = null;
      return true;
    });
  }

  void _paintLine(
    PaintingContext context,
    Offset origin,
    RenderBox child,
    int index,
    double now,
  ) {
    final data = child.parentData! as _LineParentData;
    final lines = _model.count;
    final scale = index >= lines ? 0.96 : _model.scaleOf(index, now);
    final position = origin + data.offset;
    if ((scale - 1).abs() < 0.001) {
      context.paintChild(child, position);
      return;
    }
    // Scale around the text's leading edge (or centre) so lines do not
    // wander sideways.
    final pivotX = switch (_textAlign) {
      TextAlign.center => child.size.width / 2,
      TextAlign.right || TextAlign.end => child.size.width,
      _ => 0.0,
    };
    final pivot = Offset(pivotX, child.size.height / 2);
    final transform = Matrix4.identity()
      ..translateByDouble(pivot.dx, pivot.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
    context.pushTransform(
      child.needsCompositing,
      position,
      transform,
      (context, offset) => context.paintChild(child, offset),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

// ------------------------------------------------------------------- lines

class _LyricLineView extends StatelessWidget {
  const _LyricLineView({
    super.key,
    required this.line,
    required this.active,
    required this.selected,
    required this.config,
    required this.textAlign,
    required this.preview,
    required this.clock,
    required this.nextTime,
    this.onTap,
    this.onLongPress,
  });

  final LyricLine line;
  final bool active;
  final bool selected;
  final _LineConfig config;
  final TextAlign textAlign;
  final bool preview;
  final ValueNotifier<Duration> clock;
  final Duration? nextTime;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: config.fontSize,
      fontWeight: config.weight,
      height: 1.32,
      color: context.playerInk,
      letterSpacing: preview ? 0 : -0.2,
    );
    final crossAxis = switch (textAlign) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
      _ => CrossAxisAlignment.start,
    };
    final maxLines = preview ? 1 : null;
    final Widget main;
    if (line.isEmpty) {
      main = _InterludeDots(
        start: line.time,
        end: nextTime ?? line.time + const Duration(seconds: 4),
        clock: clock,
        active: active,
        size: config.fontSize * 0.32,
      );
    } else if (active && line.hasWords) {
      main = KaraokeText(
        line: line,
        style: style,
        clock: clock,
        textAlign: textAlign,
        maxLines: maxLines,
        dimColor: context.playerInk.withValues(alpha: 0.42),
        lite: context.lowPerformance,
      );
    } else {
      main = Text(
        line.text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: preview ? TextOverflow.ellipsis : null,
      );
    }
    final sub = TextStyle(
      fontSize: config.fontSize * 0.62,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: context.playerInk.withValues(alpha: 0.72),
    );
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxis,
      children: [
        main,
        if (config.romaji && (line.romaji ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(line.romaji!, style: sub, textAlign: textAlign),
        ],
        if (config.translation && (line.translation ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(line.translation!, style: sub, textAlign: textAlign),
        ],
      ],
    );
    if (onTap == null && onLongPress == null) return content;
    content = AnimatedContainer(
      duration: AppMotion.quick,
      curve: AppMotion.enter,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.playerInk.withValues(alpha: selected ? 0.14 : 0),
        borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
      ),
      child: content,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: content,
    );
  }
}

/// Three dots that fill during an instrumental gap.
class _InterludeDots extends StatelessWidget {
  const _InterludeDots({
    required this.start,
    required this.end,
    required this.clock,
    required this.active,
    required this.size,
  });

  final Duration start;
  final Duration end;
  final ValueNotifier<Duration> clock;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size * 3,
      width: size * 7,
      child: active
          ? CustomPaint(
              painter: _DotsPainter(
                clock: clock,
                start: start,
                end: end,
                dot: size,
                color: context.playerInk,
              ),
            )
          : CustomPaint(
              painter: _DotsPainter(
                clock: null,
                start: start,
                end: end,
                dot: size,
                color: context.playerInk,
              ),
            ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.clock,
    required this.start,
    required this.end,
    required this.dot,
    required this.color,
  }) : super(repaint: clock);

  final ValueNotifier<Duration>? clock;
  final Duration start;
  final Duration end;
  final double dot;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final span = (end - start).inMilliseconds;
    final progress = clock == null || span <= 0
        ? 0.0
        : ((clock!.value - start).inMilliseconds / span).clamp(0.0, 1.0);
    final breathe = clock == null
        ? 1.0
        : 1 + 0.12 * math.sin(clock!.value.inMilliseconds / 260);
    for (var i = 0; i < 3; i++) {
      final fill = (progress * 3 - i).clamp(0.0, 1.0);
      final paint = Paint()..color = color.withValues(alpha: 0.3 + 0.7 * fill);
      canvas.drawCircle(
        Offset(dot + i * dot * 2.4, size.height / 2),
        dot / 2 * breathe,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.color != color ||
      old.clock != clock ||
      old.start != start ||
      old.end != end;
}

class _ResumeChip extends StatelessWidget {
  const _ResumeChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: context.playerInk.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.my_location_rounded, size: 15, color: s.lime),
            const SizedBox(width: 6),
            Text(
              '回到当前',
              style: TextStyle(color: context.playerInk, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades + scales a child in and out (keeps it mounted while hidden).
class _FadeScale extends StatelessWidget {
  const _FadeScale({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.standard,
        curve: AppMotion.enter,
        child: AnimatedScale(
          scale: visible ? 1 : 0.92,
          duration: AppMotion.standard,
          curve: visible ? AppMotion.pop : AppMotion.exit,
          child: child,
        ),
      ),
    );
  }
}
