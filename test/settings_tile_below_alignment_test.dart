import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/settings/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: Size(1200, 800)),
  child: MaterialApp(
    theme: AppTheme.build(Brightness.dark),
    home: Scaffold(body: child),
  ),
);

Widget _sizeText() => const AnimatedSwitcher(
  duration: Duration(milliseconds: 200),
  child: Text('5.2 MB', key: ValueKey('size')),
);

void main() {
  testWidgets('SettingsTile below content is start-aligned, not centered', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SettingsTile(
          label: '图片缓存',
          below: _sizeText(),
          trailing: const SizedBox(width: 40, height: 24),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labelTopLeft = tester.getTopLeft(find.text('图片缓存'));
    final belowTopLeft = tester.getTopLeft(find.text('5.2 MB'));

    // The size text must hug the same left edge as the label (18px tile
    // padding), not be centered across the row by AnimatedSwitcher's Stack.
    expect(belowTopLeft.dx, labelTopLeft.dx);
    expect(belowTopLeft.dy, greaterThan(labelTopLeft.dy));
  });

  testWidgets('subtitleWidget sits tight under the label like a subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SettingsTile(
          label: '图片缓存',
          subtitleWidget: _sizeText(),
          trailing: const SizedBox(width: 40, height: 24),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labelBottom = tester.getBottomLeft(find.text('图片缓存'));
    final sizeTopLeft = tester.getTopLeft(find.text('5.2 MB'));

    // Same 3px gap and left edge as the String subtitle slot.
    expect(sizeTopLeft.dx, labelBottom.dx);
    expect(sizeTopLeft.dy - labelBottom.dy, 3);
  });
}
