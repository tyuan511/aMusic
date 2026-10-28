import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/browse_widgets/sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shell draws the mini player and the floating navigation inside the page
/// tree (`Stack` under the `Scaffold` body). Anything pushed on a branch
/// navigator renders *inside* that body, i.e. below the floating chrome, which
/// is how the song menu used to get covered at the bottom of the screen.
/// [showAppSheet] pushes on the root navigator so sheets land in the app-wide
/// overlay instead.
void main() {
  testWidgets('sheets are pushed on the root navigator, not the branch one', (
    tester,
  ) async {
    final branchKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Navigator(
                  key: branchKey,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (context) => Center(
                      child: TextButton(
                        onPressed: () => showAppSheet<void>(
                          context,
                          builder: (_) => const SizedBox(
                            height: 200,
                            child: Text('sheet body'),
                          ),
                        ),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                ),
              ),
              // Stands in for the floating mini player / navigation pill.
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(height: 120, child: Text('chrome')),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);

    final sheetContext = tester.element(find.text('sheet body'));
    final owner = Navigator.of(sheetContext);
    final root = Navigator.of(branchKey.currentContext!, rootNavigator: true);
    expect(identical(owner, root), isTrue);
    expect(identical(owner, branchKey.currentState), isFalse);
  });
}
