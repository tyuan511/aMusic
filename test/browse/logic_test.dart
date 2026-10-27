import 'package:amusic/models/discovery.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/ui/browse_widgets/detail_header.dart';
import 'package:amusic/ui/browse_widgets/layout.dart';
import 'package:amusic/ui/browse_widgets/media_cards.dart';
import 'package:amusic/ui/browse_widgets/track_entries.dart';
import 'package:amusic/ui/charts/chart_groups.dart';
import 'package:amusic/ui/home/home_feed.dart';
import 'package:amusic/ui/library/create_playlist_dialog.dart';
import 'package:amusic/ui/widgets/cover_image.dart';
import 'package:amusic/ui/widgets/like_button.dart';
import 'package:amusic/models/album.dart';
import 'package:flutter_test/flutter_test.dart';

Song song(
  int id,
  String name, {
  String artist = '周杰伦',
  String album = '叶惠美',
  int? cd,
  int? no,
  SongFee fee = SongFee.free,
  bool playable = true,
  String? maxLevel,
}) => Song(
  id: id,
  name: name,
  artists: [Artist(id: 1, name: artist)],
  album: AlbumRef(id: 9, name: album),
  duration: const Duration(minutes: 4),
  cd: cd,
  no: no,
  fee: fee,
  playable: playable,
  maxLevel: maxLevel,
);

void main() {
  group('greeting', () {
    test('by hour', () {
      expect(greetingFor(2), '夜深了');
      expect(greetingFor(7), '早上好');
      expect(greetingFor(12), '中午好');
      expect(greetingFor(15), '下午好');
      expect(greetingFor(21), '晚上好');
    });

    test('line with and without nickname', () {
      expect(greetingLine(21, 'Samantha'), '晚上好，Samantha');
      expect(greetingLine(9, null), '早上好');
      expect(greetingLine(9, '  '), '早上好');
    });
  });

  group('track entries', () {
    final tracks = [
      song(1, '晴天', cd: 1, no: 1),
      song(2, '七里香', artist: '周杰伦', cd: 1, no: 2),
      song(3, 'Hello', artist: 'Adele', album: '25', cd: 2, no: 1),
    ];

    test('playlist rows are numbered by position, no disc headers', () {
      final entries = buildTrackEntries(tracks);
      expect(entries, hasLength(3));
      expect((entries[2] as SongEntry).label, '03');
    });

    test('albums group by disc with album track numbers', () {
      final entries = buildTrackEntries(tracks, byDisc: true);
      expect(entries.map((e) => e.runtimeType).toList(), [
        DiscHeaderEntry,
        SongEntry,
        SongEntry,
        DiscHeaderEntry,
        SongEntry,
      ]);
      expect((entries[4] as SongEntry).label, '01');
      expect((entries[3] as DiscHeaderEntry).disc, 2);
    });

    test('single disc albums have no headers', () {
      final entries = buildTrackEntries(tracks.take(2).toList(), byDisc: true);
      expect(entries.whereType<DiscHeaderEntry>(), isEmpty);
    });

    test('filter matches title, artist and album, keeps source index', () {
      final byArtist = buildTrackEntries(tracks, query: 'adele');
      expect(byArtist, hasLength(1));
      expect((byArtist.single as SongEntry).sourceIndex, 2);

      final byAlbum = buildTrackEntries(tracks, query: '叶惠美', byDisc: true);
      expect(byAlbum, hasLength(2));
      expect(byAlbum.whereType<DiscHeaderEntry>(), isEmpty);

      expect(buildTrackEntries(tracks, query: '晴'), hasLength(1));
      expect(buildTrackEntries(tracks, query: 'zzz'), isEmpty);
    });

    test('songMatches ignores case and whitespace', () {
      expect(songMatches(song(1, 'Hello World'), '  hello '), isTrue);
      expect(songMatches(song(1, 'x'), ''), isTrue);
    });
  });

  group('locate current offset math', () {
    final entries = buildTrackEntries([
      song(1, 'a', cd: 1),
      song(2, 'b', cd: 1),
      song(3, 'c', cd: 2),
      song(4, 'd', cd: 2),
    ], byDisc: true);

    test('entry offsets account for disc headers', () {
      expect(entryIndexOfSong(entries, 3), 4);
      expect(entryIndexOfSong(entries, 99), -1);
      expect(entryIndexOfSong(entries, null), -1);
      expect(
        entryOffset(entries, 4),
        2 * kDiscHeaderExtent + 2 * kTrackRowExtent,
      );
    });

    test('offscreen detection respects floating insets', () {
      // Row at 1000-1064, viewport 0-800: hidden.
      expect(
        isRowOffscreen(
          rowTop: 1000,
          extent: 64,
          scrollOffset: 0,
          viewport: 800,
        ),
        isTrue,
      );
      // Visible in the middle.
      expect(
        isRowOffscreen(rowTop: 300, extent: 64, scrollOffset: 0, viewport: 800),
        isFalse,
      );
      // Under the floating player (bottom 168 px) counts as hidden.
      expect(
        isRowOffscreen(
          rowTop: 700,
          extent: 64,
          scrollOffset: 0,
          viewport: 800,
          bottomInset: 168,
        ),
        isTrue,
      );
      // Under the sticky header counts as hidden.
      expect(
        isRowOffscreen(
          rowTop: 500,
          extent: 64,
          scrollOffset: 450,
          viewport: 800,
          topInset: 120,
        ),
        isTrue,
      );
    });

    test('centred target is clamped to the scroll range', () {
      expect(
        centeredScrollTarget(
          rowTop: 2000,
          extent: 64,
          viewport: 800,
          maxScrollExtent: 5000,
        ),
        2000 - (800 - 64) / 2,
      );
      expect(
        centeredScrollTarget(
          rowTop: 100,
          extent: 64,
          viewport: 800,
          maxScrollExtent: 5000,
        ),
        0,
      );
      expect(
        centeredScrollTarget(
          rowTop: 4900,
          extent: 64,
          viewport: 800,
          maxScrollExtent: 4500,
        ),
        4500,
      );
      // With insets the row is centred in the visible window.
      expect(
        centeredScrollTarget(
          rowTop: 2000,
          extent: 64,
          viewport: 800,
          maxScrollExtent: 5000,
          topInset: 100,
          bottomInset: 100,
        ),
        2000 - 100 - (600 - 64) / 2,
      );
    });
  });

  group('charts', () {
    test('groups official, global and featured', () {
      const lists = [
        Toplist(id: 1, name: '飙升榜', isOfficial: true),
        Toplist(id: 2, name: '美国Billboard榜'),
        Toplist(id: 3, name: '日本Oricon榜'),
        Toplist(id: 4, name: '说唱榜'),
        Toplist(id: 5, name: 'UK排行榜周榜'),
      ];
      final groups = groupCharts(lists);
      expect(groups.official.map((l) => l.id), [1]);
      expect(groups.global.map((l) => l.id), [2, 3, 5]);
      expect(groups.featured.map((l) => l.id), [4]);
      expect(groupCharts(const []).isEmpty, isTrue);
    });
  });

  group('misc', () {
    test('song badge labels', () {
      expect(songBadgeLabels(song(1, 'a')), isEmpty);
      expect(songBadgeLabels(song(1, 'a', fee: SongFee.vip)), ['VIP']);
      expect(songBadgeLabels(song(1, 'a', fee: SongFee.trial)), ['试听']);
      expect(songBadgeLabels(song(1, 'a', maxLevel: 'lossless')), ['SQ']);
      expect(songBadgeLabels(song(1, 'a', maxLevel: 'hires')), ['Hi-Res']);
      expect(songBadgeLabels(song(1, 'a', maxLevel: 'exhigh')), isEmpty);
      expect(songBadgeLabels(song(1, 'a', fee: SongFee.vip, playable: false)), [
        '无版权',
      ]);
    });

    test('playlist name validation', () {
      expect(validatePlaylistName('  '), isNotNull);
      expect(validatePlaylistName('我的歌单'), isNull);
      expect(validatePlaylistName('a' * 40), isNull);
      expect(validatePlaylistName('a' * 41), isNotNull);
    });

    test('local cover detection', () {
      expect(CoverImage.isLocal('file:///tmp/a.jpg'), isTrue);
      expect(CoverImage.isLocal('/storage/emulated/0/a.jpg'), isTrue);
      expect(CoverImage.isLocal(r'C:\music\a.jpg'), isTrue);
      expect(CoverImage.isLocal('https://p1.music.126.net/a.jpg'), isFalse);
      expect(CoverImage.providerFor(null), isNull);
      expect(CoverImage.providerFor(''), isNull);
    });

    test('content padding centres the max width', () {
      expect(contentSidePadding(800), 0);
      expect(contentSidePadding(kContentMaxWidth + 200), 100);
    });

    test('collapse progress', () {
      expect(collapseProgress(0, 260), 0);
      expect(collapseProgress(260, 260), 1);
      expect(collapseProgress(228, 260), closeTo(0.5, 1e-9));
    });

    test('singles / EP detection', () {
      expect(
        isSingleOrEp(const Album(id: 1, name: 'a', type: 'Single')),
        isTrue,
      );
      expect(
        isSingleOrEp(const Album(id: 1, name: 'a', type: 'EP/Single')),
        isTrue,
      );
      expect(isSingleOrEp(const Album(id: 1, name: 'a', type: '专辑')), isFalse);
      expect(isSingleOrEp(const Album(id: 1, name: 'a')), isFalse);
    });
  });
}
