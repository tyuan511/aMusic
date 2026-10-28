import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/browse_widgets/detail_header.dart';
import 'package:amusic/ui/widgets/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Distance between the top edge of [CollapsingHeaderBar] and the round
/// buttons inside it — the gap the user actually sees under the window edge.
double _buttonTopGap(WidgetTester tester) {
  final bar = tester.getTopLeft(find.byType(CollapsingHeaderBar)).dy;
  final button = tester.getTopLeft(find.byType(RoundIconButton).first).dy;
  return button - bar;
}

Future<void> _pump(WidgetTester tester, EdgeInsets systemPadding) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(padding: systemPadding),
        child: Scaffold(
          body: CollapsingHeaderBar(
            controller: controller,
            title: '测试歌单',
            actions: [
              RoundIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: '更多',
                size: 42,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('keeps a gap from the window edge without a status bar', (
    tester,
  ) async {
    await _pump(tester, EdgeInsets.zero);
    expect(_buttonTopGap(tester), kHeaderBarTopGap);
    expect(kHeaderBarTopGap, greaterThan(0));
  });

  testWidgets('follows the system inset when there is one', (tester) async {
    await _pump(tester, const EdgeInsets.only(top: 47));
    expect(_buttonTopGap(tester), 47);
  });
}
