import 'package:amusic/audio/eq/eq_model.dart';
import 'package:amusic/services/app.dart';
import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/eq/equalizer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  SoundTab tab = SoundTab.equalizer,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: Scaffold(body: EqualizerPanel(initialTab: tab)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// `testWidgets` that settles the equalizer's debounce timers before the
/// framework checks for leaked timers.
void eqTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    app.eq.dispose();
  });
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app = await AppServices.bootstrap();
  });

  for (final size in const [Size(390, 800), Size(1440, 900)]) {
    eqTest('renders without overflow @${size.width.toInt()}', (tester) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('音效'), findsOneWidget);
      expect(find.text('均衡器'), findsOneWidget);
      expect(find.text('平直'), findsWidgets);
      expect(find.text('保存当前'), findsOneWidget);
    });

    eqTest('effects tab renders without overflow @${size.width.toInt()}', (
      tester,
    ) async {
      await _pump(tester, size, tab: SoundTab.effects);
      expect(tester.takeException(), isNull);
      final shown = SoundEffects.all;
      expect(shown.length, 6);
      for (final effect in shown) {
        expect(find.text(effect.name), findsOneWidget);
        expect(find.text(effect.description), findsOneWidget);
      }
    });
  }

  eqTest('tapping an effect card selects it, tapping again turns it off', (
    tester,
  ) async {
    await _pump(tester, const Size(600, 800), tab: SoundTab.effects);
    expect(app.eq.settings.effect, isNull);
    await tester.tap(find.text('超重低音'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.eq.settings.effect?.id, 'superBass');
    expect(soundSummary(app.eq.value), '超重低音');
    await tester.tap(find.text('超重低音'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.eq.settings.effect, isNull);
    expect(app.eq.settings.effectId, 'superBass');
  });

  eqTest('choosing an effect switches the equalizer off and vice versa', (
    tester,
  ) async {
    await _pump(tester, const Size(600, 800), tab: SoundTab.effects);
    app.eq.applyPreset(EqPresets.byId('rock')!);
    await tester.pump();
    expect(app.eq.settings.enabled, isTrue);

    await tester.tap(find.text('清澈人声'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.eq.settings.effect?.id, 'clearVocal');
    expect(app.eq.settings.enabled, isFalse);

    await tester.tap(find.text('均衡器'));
    await tester.pump(const Duration(milliseconds: 400));
    final rect = tester.getRect(find.byType(EqStage));
    await tester.tapAt(Offset(rect.left + rect.width * 0.55, rect.top + 40));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.eq.settings.enabled, isTrue);
    expect(app.eq.settings.effect, isNull);
    expect(soundSummary(app.eq.value), isNot(contains('清澈人声')));
  });

  eqTest('the header switch drives the effect and the tabs switch pages', (
    tester,
  ) async {
    await _pump(tester, const Size(600, 800), tab: SoundTab.effects);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.eq.settings.effectEnabled, isTrue);

    await tester.tap(find.text('均衡器'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EqStage), findsOneWidget);
    expect(app.eq.settings.enabled, isFalse); // the effect is what is on
  });

  eqTest('dragging the stage sets a band and switches the EQ on', (
    tester,
  ) async {
    await _pump(tester, const Size(600, 800));
    expect(app.eq.settings.enabled, isFalse);

    final stage = find.byType(EqStage);
    final rect = tester.getRect(stage);
    // Sixth column (1 kHz), a quarter of the way down => a boost.
    final x = rect.left + rect.width * 0.55;
    final gesture = await tester.startGesture(Offset(x, rect.top + 40));
    await tester.pump();
    await gesture.moveTo(Offset(x, rect.top + 50));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(app.eq.settings.enabled, isTrue);
    expect(app.eq.settings.gains[5], greaterThan(6));
    expect(app.eq.settings.presetId, isNull);
    expect(tester.takeException(), isNull);
  });

  eqTest('double tap flattens a band', (tester) async {
    await _pump(tester, const Size(600, 800));
    app.eq.applyPreset(EqPresets.byId('bass')!);
    await tester.pump();
    expect(app.eq.settings.gains[0], greaterThan(0));

    final rect = tester.getRect(find.byType(EqStage));
    final p = Offset(rect.left + rect.width * 0.05, rect.center.dy - 30);
    await tester.tapAt(p);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tapAt(p);
    await tester.pump(const Duration(milliseconds: 400));

    expect(app.eq.settings.gains[0], 0);
  });

  eqTest('choosing a preset selects it', (tester) async {
    await _pump(tester, const Size(600, 800));
    await tester.tap(find.text('摇滚'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.eq.settings.enabled, isTrue);
    expect(app.eq.settings.presetId, 'rock');
    expect(eqSummary(app.eq.value), '摇滚');
  });
}
