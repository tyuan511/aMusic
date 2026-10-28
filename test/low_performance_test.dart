import 'package:amusic/core/prefs.dart';
import 'package:amusic/services/settings_service.dart';
import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/widgets/kit.dart';
import 'package:amusic/ui/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child, {required bool low}) => MaterialApp(
  theme: AppTheme.build(Brightness.dark),
  home: LowPerformanceScope(
    enabled: low,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  test('low performance persists and overrides blur and backdrop', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService(prefs, readSettings(prefs));

    expect(settings.value.lowPerformance, isFalse);
    expect(settings.value.useLyricBlur, isTrue);
    expect(settings.value.useDynamicBackground, isTrue);

    settings.update((s) => s.copyWith(lowPerformance: true));
    expect(prefs.getKeys(), {PrefsKeys.lowPerformance});
    final restored = readSettings(prefs);
    expect(restored.lowPerformance, isTrue);
    // The user's own choices survive; they are just not drawn.
    expect(restored.lyricBlur, isTrue);
    expect(restored.useLyricBlur, isFalse);
    expect(restored.useDynamicBackground, isFalse);
  });

  testWidgets('GlassPanel drops the backdrop blur in low performance mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const GlassPanel(child: Text('bar')), low: false),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.pumpWidget(
      _host(const GlassPanel(child: Text('bar')), low: true),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('bar'), findsOneWidget);
  });

  testWidgets('AmbientClock ticks only while someone listens', (tester) async {
    var ticks = 0;
    void listener() => ticks++;

    AmbientClock.instance.addListener(listener);
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks, 3);

    AmbientClock.instance.removeListener(listener);
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks, 3);
  });
}
