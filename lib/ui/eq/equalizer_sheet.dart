import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../audio/eq/eq_dsp.dart';
import '../../audio/eq/eq_model.dart';
import '../../audio/eq/eq_service.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/sheets.dart';
import '../widgets/kit.dart';

enum SoundTab { effects, equalizer }

/// 音效 / 均衡器 as a bottom sheet (player screen and settings share it).
Future<void> showEqualizerSheet(
  BuildContext context, {
  SoundTab tab = SoundTab.effects,
}) => showAppSheet<void>(
  context,
  isScrollControlled: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.9,
    child: SafeArea(top: false, child: EqualizerPanel(initialTab: tab)),
  ),
);

/// One line describing the equalizer, for settings rows and tooltips.
String eqSummary(EqState state) {
  if (!state.settings.enabled) return '已关闭';
  if (state.settings.isFlat) return '平直';
  return state.activePreset?.name ?? '自定义';
}

/// One line describing the sound effect.
String effectSummary(EqState state) => state.settings.effect?.name ?? '已关闭';

/// "超重低音 · 均衡器 摇滚" style summary of everything that is on.
String soundSummary(EqState state) {
  final parts = [
    if (state.settings.effect != null) state.settings.effect!.name,
    if (state.settings.enabled && !state.settings.isFlat)
      '均衡器 ${eqSummary(state)}',
  ];
  return parts.isEmpty ? '已关闭' : parts.join(' · ');
}

String _dbText(double db) => '${db.toStringAsFixed(1)} dB';

/// The whole panel: tabs for the one tap effects and the ten band equalizer.
class EqualizerPanel extends StatefulWidget {
  const EqualizerPanel({super.key, this.initialTab = SoundTab.effects});

  final SoundTab initialTab;

  @override
  State<EqualizerPanel> createState() => _EqualizerPanelState();
}

class _EqualizerPanelState extends State<EqualizerPanel> {
  late SoundTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EqState>(
      valueListenable: app.eq,
      builder: (context, state, _) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                _Header(
                  state: state,
                  tab: _tab,
                  onTab: (tab) => setState(() => _tab = tab),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.standard,
                    child: _tab == SoundTab.effects
                        ? _EffectsTab(key: const ValueKey('fx'), state: state)
                        : _EqTab(key: const ValueKey('eq'), state: state),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.tab, required this.onTab});

  final EqState state;
  final SoundTab tab;
  final ValueChanged<SoundTab> onTab;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final settings = state.settings;
    final effects = tab == SoundTab.effects;
    final on = effects ? settings.effect != null : settings.enabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            _TabLabel(
              label: '音效',
              selected: effects,
              onTap: () => onTab(SoundTab.effects),
            ),
            const SizedBox(width: 22),
            _TabLabel(
              label: '均衡器',
              selected: !effects,
              onTap: () => onTab(SoundTab.equalizer),
            ),
            const Spacer(),
            if (box.maxWidth > 420)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AnimatedSwitcher(
                  duration: AppMotion.quick,
                  child: Text(
                    effects
                        ? '音效：${effectSummary(state)}'
                        : '均衡器：${eqSummary(state)}',
                    key: ValueKey('$effects${effectSummary(state)}'),
                    style: context.text.bodySmall?.copyWith(
                      color: on ? s.lime : s.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Switch(
              value: on,
              onChanged: effects ? app.eq.setEffectEnabled : app.eq.setEnabled,
            ),
            IconButton(
              tooltip: '关闭',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: AppMotion.quick,
            style: context.text.titleLarge!.copyWith(
              color: selected ? context.colors.onSurface : s.textTertiary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: AppMotion.standard,
            curve: AppMotion.enter,
            width: selected ? 22 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: s.lime,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ effects

class _EffectsTab extends StatelessWidget {
  const _EffectsTab({super.key, required this.state});

  final EqState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(
          '推荐音效',
          style: context.text.titleSmall?.copyWith(
            color: context.surfaces.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 12.0;
            final columns = box.maxWidth >= 360 ? 2 : 1;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final effect in SoundEffects.available)
                  SizedBox(
                    width: width,
                    height: 112,
                    child: _EffectCard(
                      effect: effect,
                      selected:
                          settings.effectEnabled &&
                          settings.effectId == effect.id,
                      onTap: () =>
                          settings.effectEnabled &&
                              settings.effectId == effect.id
                          ? app.eq.setEffectEnabled(false)
                          : app.eq.selectEffect(effect.id),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _EffectLoudnessRow(settings: settings),
        const SizedBox(height: 18),
        Text(
          '音效与均衡器同一时间只能开启一个，选择其一会自动关闭另一个。',
          style: context.text.bodySmall?.copyWith(
            color: context.surfaces.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _EffectLoudnessRow extends StatelessWidget {
  const _EffectLoudnessRow({required this.settings});

  final EqSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final loudness = settings.effectLoudness;
    final text = '${loudness > 0 ? '+' : ''}${loudness.toStringAsFixed(1)} dB';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('音效响度', style: context.text.titleSmall),
            const Spacer(),
            Text(
              text,
              style: context.text.labelLarge?.copyWith(
                color: settings.effect != null ? s.lime : s.textTertiary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: loudness,
          min: effectMinLoudness,
          max: effectMaxLoudness,
          divisions: ((effectMaxLoudness - effectMinLoudness) * 2).round(),
          label: text,
          onChanged: app.eq.setEffectLoudness,
        ),
        Text(
          '只调节音效处理后的响度，不会改变主音量',
          style: context.text.bodySmall?.copyWith(color: s.textTertiary),
        ),
      ],
    );
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.effect,
    required this.selected,
    required this.onTap,
  });

  final SoundEffect effect;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      semanticLabel: effect.name,
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.enter,
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        decoration: BoxDecoration(
          color: selected ? s.lime.withValues(alpha: 0.12) : s.chip,
          borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
          border: Border.all(
            color: selected ? s.lime : s.hairline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    effect.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: AppMotion.quick,
                  opacity: selected ? 1 : 0,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: s.lime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: Text(
                effect.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: s.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- equalizer

class _EqTab extends StatelessWidget {
  const _EqTab({super.key, required this.state});

  final EqState state;

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        AnimatedOpacity(
          duration: AppMotion.standard,
          opacity: settings.enabled ? 1 : 0.5,
          child: EqStage(
            gains: settings.gains,
            enabled: settings.enabled,
            onBand: app.eq.setBand,
          ),
        ),
        const SizedBox(height: 8),
        const _FrequencyLabels(),
        const SizedBox(height: 18),
        _PreampRow(settings: settings),
        const SizedBox(height: 22),
        _PresetSection(state: state),
      ],
    );
  }
}

// -------------------------------------------------------------------- stage

const double _stageHeight = 230;
const double _stagePad = 18;

/// The interactive curve. Ten columns, one per band; press and drag anywhere
/// to set the band under the finger, so a curve can simply be "painted".
/// Double tap a column to flatten it.
class EqStage extends StatefulWidget {
  const EqStage({
    super.key,
    required this.gains,
    required this.enabled,
    required this.onBand,
  });

  final List<double> gains;
  final bool enabled;
  final void Function(int band, double db) onBand;

  @override
  State<EqStage> createState() => _EqStageState();
}

class _EqStageState extends State<EqStage> {
  int? _active;
  Offset? _doubleTap;

  void _touch(Offset p, double width) {
    final band = (p.dx / width * eqBandCount).floor().clamp(0, eqBandCount - 1);
    final half = _stageHeight / 2 - _stagePad;
    var db = (_stageHeight / 2 - p.dy) / half * eqMaxGain;
    db = (db * 2).round() / 2; // 0.5 dB steps
    db = clampGain(db);
    if (db.abs() < 0.5) db = 0; // sticky zero line
    if (_active != band) {
      HapticFeedback.selectionClick();
      setState(() => _active = band);
    }
    if (widget.gains[band] != db) {
      if (db == 0) HapticFeedback.lightImpact();
      widget.onBand(band, db);
    }
  }

  void _release() => setState(() => _active = null);

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _touch(d.localPosition, width),
          onPanUpdate: (d) => _touch(d.localPosition, width),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          onDoubleTapDown: (d) => _doubleTap = d.localPosition,
          onDoubleTap: () {
            final p = _doubleTap;
            if (p == null) return;
            final band = (p.dx / width * eqBandCount).floor().clamp(
              0,
              eqBandCount - 1,
            );
            widget.onBand(band, 0);
          },
          child: SizedBox(
            height: _stageHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: s.card,
                      borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _StagePainter(
                        gains: widget.gains,
                        active: _active,
                        accent: widget.enabled ? s.lime : s.textTertiary,
                        grid: s.hairline,
                        label: s.textTertiary,
                        thumbCore: s.onLime,
                        textStyle: context.text.labelSmall!,
                      ),
                    ),
                  ),
                ),
                // Screen readers get ten sliders instead of one painting.
                Positioned.fill(
                  child: Row(
                    children: [
                      for (var i = 0; i < eqBandCount; i++)
                        Expanded(
                          child: Semantics(
                            slider: true,
                            label: '${eqFrequencyLabel(eqFrequencies[i])} Hz',
                            value: _dbText(widget.gains[i]),
                            increasedValue: _dbText(
                              clampGain(widget.gains[i] + 1),
                            ),
                            decreasedValue: _dbText(
                              clampGain(widget.gains[i] - 1),
                            ),
                            onIncrease: () => widget.onBand(
                              i,
                              clampGain(widget.gains[i] + 1),
                            ),
                            onDecrease: () => widget.onBand(
                              i,
                              clampGain(widget.gains[i] - 1),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.gains,
    required this.active,
    required this.accent,
    required this.grid,
    required this.label,
    required this.thumbCore,
    required this.textStyle,
  });

  final List<double> gains;
  final int? active;
  final Color accent;
  final Color grid;
  final Color label;
  final Color thumbCore;
  final TextStyle textStyle;

  double _y(double db, double h) =>
      h / 2 - db / eqMaxGain * (h / 2 - _stagePad);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grid: 0 dB solid, ±6 / ±12 faint, band columns.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final db in [-12.0, -6.0, 6.0, 12.0]) {
      final y = _y(db, h);
      canvas.drawLine(Offset(10, y), Offset(w - 10, y), gridPaint);
    }
    canvas.drawLine(
      Offset(10, _y(0, h)),
      Offset(w - 10, _y(0, h)),
      Paint()
        ..color = label.withValues(alpha: 0.55)
        ..strokeWidth = 1.2,
    );
    for (final db in [12, 6, 0, -6, -12]) {
      final tp = TextPainter(
        text: TextSpan(
          text: db > 0 ? '+$db' : '$db',
          style: textStyle.copyWith(
            color: label,
            fontSize: 9.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8, _y(db.toDouble(), h) - tp.height - 1));
    }

    // Response curve: sampled from the same biquad maths the engine runs.
    final bands = eqBands(gains);
    final path = Path();
    const steps = 180;
    for (var i = 0; i <= steps; i++) {
      final x = w * i / steps;
      final hz = eqFrequencies.first * math.pow(2, x / w * eqBandCount - 0.5);
      final db = responseDb(bands, hz.toDouble()).clamp(-eqMaxGain, eqMaxGain);
      final y = _y(db.toDouble(), h);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo(w, _y(0, h))
      ..lineTo(0, _y(0, h))
      ..close();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.30),
            accent.withValues(alpha: 0.04),
            accent.withValues(alpha: 0.30),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Band handles.
    final col = w / eqBandCount;
    for (var i = 0; i < eqBandCount; i++) {
      final x = col * (i + 0.5);
      final y = _y(gains[i], h);
      final isActive = active == i;
      if (isActive) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - col / 2 + 3, 6, col - 6, h - 12),
            const Radius.circular(10),
          ),
          Paint()..color = accent.withValues(alpha: 0.10),
        );
      }
      canvas.drawLine(
        Offset(x, _y(0, h)),
        Offset(x, y),
        Paint()
          ..color = accent.withValues(alpha: isActive ? 0.9 : 0.5)
          ..strokeWidth = 2,
      );
      if (isActive) {
        canvas.drawCircle(
          Offset(x, y),
          15,
          Paint()..color = accent.withValues(alpha: 0.22),
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        isActive ? 8.5 : 6.5,
        Paint()..color = accent,
      );
      canvas.drawCircle(Offset(x, y), 2.6, Paint()..color = thumbCore);
    }

    // Read-out bubble above the band being dragged.
    final a = active;
    if (a != null) {
      final db = gains[a];
      final tp = TextPainter(
        text: TextSpan(
          text:
              '${eqFrequencyLabel(eqFrequencies[a])} Hz   '
              '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)} dB',
          style: textStyle.copyWith(
            color: thumbCore,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bw = tp.width + 20;
      final bx = (col * (a + 0.5) - bw / 2).clamp(6.0, w - bw - 6);
      final by = _y(db, h) < 54 ? _y(db, h) + 22 : _y(db, h) - 46;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, bw, 28),
          const Radius.circular(14),
        ),
        Paint()..color = accent,
      );
      tp.paint(canvas, Offset(bx + 10, by + (28 - tp.height) / 2));
    }
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.active != active ||
      old.accent != accent ||
      old.grid != grid ||
      old.gains != gains;
}

class _FrequencyLabels extends StatelessWidget {
  const _FrequencyLabels();

  @override
  Widget build(BuildContext context) {
    final style = context.text.labelSmall?.copyWith(
      color: context.surfaces.textTertiary,
    );
    return Row(
      children: [
        for (final hz in eqFrequencies)
          Expanded(
            child: Text(
              eqFrequencyLabel(hz),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------- preamp

class _PreampRow extends StatelessWidget {
  const _PreampRow({required this.settings});

  final EqSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    String db(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)} dB';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('前级增益', style: context.text.titleSmall),
            const Spacer(),
            Text(
              db(settings.preamp),
              style: context.text.labelLarge?.copyWith(
                color: settings.enabled ? s.lime : s.textTertiary,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        Slider(
          value: settings.preamp,
          min: -eqMaxGain,
          max: eqMaxPreamp,
          divisions: ((eqMaxGain + eqMaxPreamp) * 2).round(),
          label: db(settings.preamp),
          onChanged: app.eq.setPreamp,
        ),
        Text(
          '拖动曲线调节各频段，双击某一列可归零',
          style: context.text.bodySmall?.copyWith(color: s.textTertiary),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ presets

class _PresetSection extends StatelessWidget {
  const _PresetSection({required this.state});

  final EqState state;

  @override
  Widget build(BuildContext context) {
    final selected = state.settings.presetId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('预设', style: context.text.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final preset in state.presets)
              GestureDetector(
                onLongPress: preset.builtIn
                    ? null
                    : () => _confirmDelete(context, preset),
                child: PillChip(
                  label: preset.name,
                  dense: true,
                  selected: state.settings.enabled && selected == preset.id,
                  onTap: () => app.eq.applyPreset(preset),
                ),
              ),
            PillChip(
              label: '保存当前',
              icon: Icons.add_rounded,
              dense: true,
              selected: false,
              onTap: () => _save(context),
            ),
          ],
        ),
        if (state.custom.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '长按自定义预设可删除',
            style: context.text.bodySmall?.copyWith(
              color: context.surfaces.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _save(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: const Text('保存为预设'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(hintText: '预设名称'),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) app.eq.saveCustom(name);
  }

  Future<void> _confirmDelete(BuildContext context, EqPreset preset) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text('删除“${preset.name}”？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) app.eq.deleteCustom(preset.id);
  }
}
