import 'package:amusic/models/song.dart';
import 'package:amusic/services/app.dart';
import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/browse_widgets/cards.dart';
import 'package:amusic/ui/home/home_hero.dart';
import 'package:amusic/ui/search/search_discovery.dart';
import 'package:amusic/ui/widgets/kit.dart';
import 'package:amusic/ui/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _song(
  int id,
  String name, {
  SongFee fee = SongFee.free,
  bool playable = true,
  String? maxLevel,
}) => Song(
  id: id,
  name: name,
  artists: const [
    Artist(id: 1, name: '周杰伦'),
    Artist(id: 2, name: '费玉清'),
  ],
  album: const AlbumRef(id: 9, name: '叶惠美'),
  duration: const Duration(minutes: 4, seconds: 5),
  fee: fee,
  playable: playable,
  maxLevel: maxLevel,
);

Widget _host(Widget child, {Size size = const Size(1200, 800)}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    theme: AppTheme.build(Brightness.dark),
    home: Scaffold(body: child),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app = await AppServices.bootstrap();
  });

  testWidgets('SongTile renders title, artists, badges and duration', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            SongTile(
              song: _song(1, '晴天', fee: SongFee.vip, maxLevel: 'lossless'),
              showAlbum: true,
            ),
            SongTile(song: _song(2, '七里香', fee: SongFee.trial), index: 1),
            SongTile(song: _song(3, '下架歌曲', playable: false)),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('晴天'), findsOneWidget);
    expect(find.text('周杰伦 / 费玉清'), findsNWidgets(3));
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('SQ'), findsOneWidget);
    expect(find.text('试听'), findsOneWidget);
    expect(find.text('无版权'), findsOneWidget);
    expect(find.text('4:05'), findsNWidgets(3));
    expect(find.text('叶惠美'), findsOneWidget);
    // Numbered row shows its track number.
    expect(find.text('2'), findsOneWidget);
    // Greyed out row is dimmed.
    final dimmed = tester.widgetList<AnimatedOpacity>(
      find.ancestor(
        of: find.text('下架歌曲'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(dimmed.any((o) => o.opacity < 1), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SongTile hides album and duration on narrow rows', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 340,
          child: SongTile(song: _song(1, '晴天'), showAlbum: true),
        ),
        size: const Size(400, 800),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('叶惠美'), findsNothing);
    expect(find.text('4:05'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SongTile columns follow the row width, not the window', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        // A wide window with a narrow column: the album must not appear.
        SizedBox(
          width: 480,
          child: SongTile(song: _song(1, '晴天'), showAlbum: true),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('叶惠美'), findsNothing);
    expect(find.text('4:05'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hot list highlights the top three ranks in lime', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            for (var i = 1; i <= 4; i++)
              HotWordRow(rank: i, word: 'word $i', onTap: () {}),
          ],
        ),
      ),
    );
    final context = tester.element(find.byType(HotWordRow).first);
    final lime = context.surfaces.lime;
    Color? colorOf(int rank) => tester
        .widget<Text>(find.byKey(ValueKey('hot-rank-$rank')))
        .style
        ?.color;
    expect(colorOf(1), lime);
    expect(colorOf(3), lime);
    expect(colorOf(4), isNot(lime));
  });

  testWidgets('page dots stretch the active dot', (tester) async {
    await tester.pumpWidget(_host(const PageDots(count: 3, index: 1)));
    await tester.pumpAndSettle();
    final dots = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .toList();
    expect(dots, hasLength(3));
    final widths = [
      for (final dot in dots) tester.getSize(find.byWidget(dot)).width,
    ];
    expect(widths[1], greaterThan(widths[0]));
  });

  testWidgets('cover card and lime pill render without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Row(
          children: [
            SizedBox(
              width: 160,
              height: CoverCard.heightFor(160),
              child: CoverCard(
                title: '一个非常非常长的歌单名字会被省略号截断',
                subtitle: 'By 某人',
                coverUrl: null,
                onTap: () {},
              ),
            ),
            LimePillButton(
              label: '播放全部',
              icon: Icons.play_arrow_rounded,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('播放全部'), findsOneWidget);
    expect(find.byType(Pressable), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
