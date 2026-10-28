import 'package:amusic/models/song.dart';
import 'package:amusic/services/app.dart';
import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/browse_widgets/layout.dart';
import 'package:amusic/ui/widgets/song_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _song(
  int id,
  String name, {
  SongFee fee = SongFee.free,
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
  maxLevel: maxLevel,
);

/// The three rows from the home screen: an album-only, a VIP Hi-Res and a
/// plain free track, so every badge combination the home grid shows is laid
/// out at every width.
final _songs = <Song>[
  _song(1, 'いよわ', fee: SongFee.album, maxLevel: 'hires'),
  _song(2, 'EasyPop', fee: SongFee.album, maxLevel: 'lossless'),
  _song(3, '破晓', fee: SongFee.vip, maxLevel: 'hires'),
  _song(4, 'If You Don\'t Mean It (ถ้าไม่คิดถึง)', fee: SongFee.trial),
];

Widget _host(Widget child, Size size) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    theme: AppTheme.build(Brightness.dark),
    home: Scaffold(body: child),
  ),
);

/// Home screen of the new-songs chip: a two-column grid of song rows.
Widget _grid(List<Song> songs) => ResponsiveColumns(
  minColumnWidth: 460,
  maxColumns: 2,
  children: [
    for (var i = 0; i < songs.length; i++)
      SongTile(song: songs[i], index: i, showAlbum: true),
  ],
);

Widget _list(List<Song> songs) => Column(
  children: [
    for (var i = 0; i < songs.length; i++)
      SongTile(song: songs[i], index: i, showAlbum: true),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app = await AppServices.bootstrap();
  });

  testWidgets('song rows never overflow, at any width', (tester) async {
    addTearDown(tester.view.reset);
    final failures = <String>[];
    for (var width = 320.0; width <= 1480; width += 20) {
      for (final entry in {'grid': _grid, 'list': _list}.entries) {
        tester.view
          ..physicalSize = Size(width, 900)
          ..devicePixelRatio = 1;
        await tester.pumpWidget(_host(entry.value(_songs), Size(width, 900)));
        await tester.pump(const Duration(milliseconds: 250));
        final error = tester.takeException();
        if (error != null) failures.add('${entry.key} @ ${width.toInt()}');
      }
    }
    expect(failures, isEmpty, reason: 'overflowing layouts: $failures');
  });

  testWidgets('columns appear only when the row is wide enough', (
    tester,
  ) async {
    addTearDown(tester.view.reset);

    // Narrow column (two-column home grid on a 1000pt window): the album
    // column no longer fits, the duration and the tags still do.
    tester.view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(_host(_grid(_songs), const Size(1000, 900)));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('叶惠美'), findsNothing);
    expect(find.text('4:05'), findsNWidgets(4));
    expect(find.text('Hi-Res'), findsNWidgets(2));
    expect(find.text('数字专辑'), findsNWidgets(2));

    // Full-width list: every column fits and comes back.
    await tester.pumpWidget(_host(_list(_songs), const Size(1000, 900)));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('叶惠美'), findsNWidgets(4));
    expect(find.text('4:05'), findsNWidgets(4));
  });

  testWidgets('the album column appears as the row gets wider', (tester) async {
    addTearDown(tester.view.reset);

    Future<double?> albumWidthAt(double width) async {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: width,
            child: SongTile(song: _song(1, '晴天'), showAlbum: true),
          ),
          Size(width, 900),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final album = find.text('叶惠美');
      if (album.evaluate().isEmpty) return null;
      final box = find.ancestor(
        of: album,
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.width != null,
        ),
      );
      return tester.getSize(box.first).width;
    }

    expect(await albumWidthAt(500), isNull);
    final narrow = await albumWidthAt(600);
    final wide = await albumWidthAt(900);
    expect(narrow, isNotNull);
    expect(narrow, lessThan(180));
    expect(wide, 180);
  });

  testWidgets('a tiny row drops the tags instead of overflowing', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view
      ..physicalSize = const Size(300, 900)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 230,
          child: SongTile(song: _songs.first, index: 0, height: 48),
        ),
        const Size(300, 900),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    expect(find.text('数字专辑'), findsNothing);
    expect(find.text('いよわ'), findsOneWidget);
  });
}
