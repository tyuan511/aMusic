import 'package:amusic/models/song.dart';
import 'package:amusic/services/app.dart';
import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/browse_widgets/track_collection_view.dart';
import 'package:amusic/ui/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Song> _tracks(int count) => [
  for (var i = 1; i <= count; i++)
    Song(
      id: i,
      name: i == 77 ? '晴天' : 'Track $i',
      artists: const [Artist(id: 1, name: '周杰伦')],
      album: const AlbumRef(id: 9, name: '叶惠美'),
      duration: const Duration(minutes: 3),
    ),
];

Future<void> _pump(WidgetTester tester, List<Song>? tracks) async {
  tester.view
    ..physicalSize = const Size(900, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: Scaffold(
        body: TrackCollectionView(
          title: '测试歌单',
          hero: const SizedBox(height: 300, child: Text('HERO')),
          tracks: tracks,
          onPlay: (_) {},
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

double _locateOpacity(WidgetTester tester) {
  final button = find.byTooltip('定位当前播放');
  final opacity = tester.widget<AnimatedOpacity>(
    find.ancestor(of: button, matching: find.byType(AnimatedOpacity)).first,
  );
  return opacity.opacity;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app = await AppServices.bootstrap();
  });

  tearDown(() => app.player.currentSongId.value = null);

  testWidgets('shows skeletons while loading, then lazy rows', (tester) async {
    await _pump(tester, null);
    expect(find.text('HERO'), findsOneWidget);
    expect(find.text('Track 1'), findsNothing);

    await _pump(tester, _tracks(200));
    expect(find.text('共 200 首'), findsOneWidget);
    expect(find.text('Track 1'), findsOneWidget);
    // Lazy: rows far below are not built.
    expect(find.text('Track 190'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-list filter narrows the rows', (tester) async {
    await _pump(tester, _tracks(120));
    await tester.enterText(find.byType(TextField), '晴天');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 / 120 首'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(SongTile), matching: find.text('晴天')),
      findsOneWidget,
    );
    expect(find.text('Track 1'), findsNothing);
  });

  testWidgets('locate button appears for an off-screen current song and '
      'scrolls to it', (tester) async {
    await _pump(tester, _tracks(150));
    expect(_locateOpacity(tester), 0);

    app.player.currentSongId.value = 120;
    await tester.pump(const Duration(milliseconds: 400));
    expect(_locateOpacity(tester), 1);

    await tester.tap(find.byTooltip('定位当前播放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Track 120'), findsOneWidget);
    expect(_locateOpacity(tester), 0);

    // A song that is not in the list never shows the button.
    app.player.currentSongId.value = 9999;
    await tester.pump(const Duration(milliseconds: 400));
    expect(_locateOpacity(tester), 0);
  });
}
