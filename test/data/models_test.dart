import 'package:amusic/data/ncm_api.dart';
import 'package:amusic/models/album.dart';
import 'package:amusic/models/artist.dart';
import 'package:amusic/models/comment.dart';
import 'package:amusic/models/discovery.dart';
import 'package:amusic/models/lyric_payload.dart';
import 'package:amusic/models/playlist.dart';
import 'package:amusic/models/search.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Toplist', () {
    test('parses preview rows and official flag from ToplistType', () {
      final list = Toplist.listFrom([
        {
          'id': 19723756,
          'name': '飙升榜',
          'coverImgUrl': 'c1',
          'updateFrequency': '刚刚更新',
          'ToplistType': 'S',
          'tracks': [
            {'first': '季候风', 'second': '王菲'},
            {'first': 'B', 'second': 'Y'},
            {'first': 'C', 'second': 'Z'},
          ],
        },
        {'id': 71384707, 'name': '古典榜', 'tracks': []},
        {'id': 0, 'name': 'broken'},
      ]);
      expect(list, hasLength(2));
      expect(list.first.isOfficial, isTrue);
      expect(list.first.toplistType, 'S');
      expect(list.first.preview.first.name, '季候风');
      expect(list.first.preview.first.artist, '王菲');
      expect(list.first.updateFrequency, '刚刚更新');
      expect(list[1].isOfficial, isFalse);
      expect(list[1].preview, isEmpty);
      expect(list.first.toPlaylist().id, 19723756);
    });

    test('falls back to the first four entries without labels', () {
      final list = Toplist.listFrom([
        for (var i = 1; i <= 6; i++) {'id': i, 'name': 'chart $i'},
      ]);
      expect(list.map((t) => t.isOfficial), [
        true,
        true,
        true,
        true,
        false,
        false,
      ]);
    });
  });

  group('Album', () {
    test('parses a search / artist album summary', () {
      final album = Album.fromJson({
        'id': 18909,
        'name': 'Partners 拍档',
        'type': '专辑',
        'size': 13,
        'blurPicUrl': 'blur',
        'publishTime': 1019750400000,
        'company': '北京亚歆',
        'artist': {'id': 6452, 'name': '周杰伦'},
        'artists': [
          {'id': 6452, 'name': '周杰伦'},
          {'id': 12203406, 'name': '方文山'},
        ],
        'alias': ['精选'],
      });
      expect(album.id, 18909);
      expect(album.picUrl, 'blur');
      expect(album.size, 13);
      expect(album.artistText, '周杰伦 / 方文山');
      expect(album.publishTime!.year, 2002);
      expect(album.alias, ['精选']);
      expect(album.tracks, isEmpty);
    });

    test('uses the single artist when the list is missing', () {
      final album = Album.fromJson({
        'id': 1,
        'name': 'x',
        'picUrl': 'p',
        'artist': {'id': 2, 'name': 'Solo'},
      });
      expect(album.artistText, 'Solo');
    });

    test('detail keeps disc / track numbers and inherits the cover', () {
      final album = Album.detailFromJson({
        'album': {
          'id': 32311,
          'name': '神的游戏',
          'picUrl': 'cover',
          'description': 'desc',
          'company': '索尼音乐',
          'subType': '录音室版',
          'size': 2,
          'artists': [
            {'id': 10557, 'name': '张悬'},
          ],
        },
        'songs': [
          {
            'id': 1,
            'name': 'a',
            'no': 1,
            'cd': '01',
            'dt': 1000,
            'ar': [
              {'id': 10557, 'name': '张悬'},
            ],
            'al': {'id': 32311, 'name': '神的游戏'},
            'privilege': {'code': 404},
          },
          {
            'id': 2,
            'name': 'b',
            'no': 2,
            'cd': '2',
            'al': {'id': 32311, 'name': '神的游戏', 'picUrl': 'own'},
          },
        ],
      });
      expect(album.company, '索尼音乐');
      expect(album.description, 'desc');
      expect(album.tracks.map((s) => s.no), [1, 2]);
      expect(album.tracks.map((s) => s.cd), [1, 2]);
      expect(album.tracks.first.album.picUrl, 'cover');
      expect(album.tracks.first.playable, isFalse);
      expect(album.tracks[1].album.picUrl, 'own');
    });
  });

  group('Artist', () {
    test('ArtistDetail parses the head/info shape', () {
      final detail = ArtistDetail.fromJson({
        'code': 200,
        'data': {
          'videoCount': 8,
          'identify': {'imageDesc': '歌手、作词、作曲'},
          'artist': {
            'id': 6452,
            'name': '周杰伦',
            'cover': 'cover',
            'avatar': 'avatar',
            'alias': ['Jay Chou', '周董'],
            'briefDesc': 'brief',
            'albumSize': 45,
            'musicSize': 582,
            'mvSize': 9,
          },
          'user': {'followed': true},
        },
      });
      expect(detail.id, 6452);
      expect(detail.avatarUrl, 'avatar');
      expect(detail.coverUrl, 'cover');
      expect(detail.alias, ['Jay Chou', '周董']);
      expect(detail.musicSize, 582);
      expect(detail.albumSize, 45);
      expect(detail.mvSize, 9);
      expect(detail.followed, isTrue);
      expect(detail.identities, ['歌手', '作词', '作曲']);
      expect(detail.ref.name, '周杰伦');
    });

    test('ArtistDetail tolerates the legacy top level artist', () {
      final detail = ArtistDetail.fromJson({
        'artist': {
          'id': 1,
          'name': 'Legacy',
          'picUrl': 'pic',
          'img1v1Url': 'https://p1.music.126.net/x==/5639395138885805.jpg', // placeholder
        },
      });
      expect(detail.name, 'Legacy');
      expect(detail.avatarUrl, 'pic');
      expect(detail.mvSize, 0);
    });

    test('artist albums page reads the more flag and total', () {
      final more = NcmApi.parseArtistAlbums({
        'artist': {'id': 6452, 'albumSize': 45},
        'hotAlbums': [
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ],
        'more': true,
      });
      expect(more.items, hasLength(2));
      expect(more.hasMore, isTrue);
      expect(more.total, 45);
      final last = NcmApi.parseArtistAlbums({'hotAlbums': [], 'more': true});
      expect(last.hasMore, isFalse, reason: 'empty page never has more');
    });

    test('Artist keeps json small and ignores placeholders', () {
      final artist = Artist.fromJson({
        'id': 1,
        'name': 'A',
        'img1v1Url': 'https://p1.music.126.net/x==/5639395138885805.jpg',
        'alia': ['Alias'],
        'trans': 'T',
      });
      expect(artist.picUrl, isNull);
      expect(artist.alias, ['Alias', 'T']);
      expect(artist.toJson(), {'id': 1, 'name': 'A'});
      expect(Artist.listFrom('nope'), isEmpty);
    });

    test('ArtistDescription keeps titled sections', () {
      final desc = ArtistDescription.fromJson({
        'briefDesc': 'b',
        'introduction': [
          {'ti': '主要成就', 'txt': 'x'},
          {'ti': 'empty', 'txt': ''},
        ],
      });
      expect(desc.sections, hasLength(1));
      expect(desc.sections.single.title, '主要成就');
      expect(desc.briefDesc, 'b');
    });
  });

  group('Comments', () {
    final user = {
      'userId': 548345,
      'nickname': '蛋蛋是圆D',
      'avatarUrl': 'a',
      'vipType': 11,
    };

    test('v2 page with beReplied and ip location', () {
      final page = CommentPage.fromV2(
        {
          'totalCount': 1970220,
          'hasMore': true,
          'cursor': '1582191360636',
          'comments': [
            {
              'commentId': 4956438,
              'content': '回复内容',
              'user': user,
              'time': 1413530574252,
              'timeStr': '2014-10-17',
              'likedCount': 823174,
              'liked': false,
              'ipLocation': {'location': '广东'},
              'beReplied': [
                {
                  'beRepliedCommentId': 1,
                  'content': '原评论',
                  'user': {'userId': 2, 'nickname': 'B'},
                },
                {
                  'beRepliedCommentId': 3,
                  'content': null,
                  'user': {'userId': 4, 'nickname': 'C'},
                },
              ],
            },
            {'commentId': 0, 'content': 'dropped'},
          ],
        },
        hotComments: [
          Comment.fromJson({'commentId': 9, 'content': 'hot', 'user': user}),
        ],
      );
      expect(page.total, 1970220);
      expect(page.hasMore, isTrue);
      expect(page.cursor, 1582191360636);
      expect(page.comments, hasLength(1));
      final comment = page.comments.single;
      expect(comment.user.nickname, '蛋蛋是圆D');
      expect(comment.user.vip, isTrue);
      expect(comment.ipLocation, '广东');
      expect(comment.timeStr, '2014-10-17');
      expect(comment.time!.year, 2014);
      expect(comment.beReplied.first.user.nickname, 'B');
      expect(comment.beReplied.first.content, '原评论');
      expect(comment.beReplied.last.content, '该评论已删除');
      expect(page.hotComments.single.content, 'hot');
      expect(comment.copyWith(liked: true, likedCount: 1).liked, isTrue);
    });

    test('hot sort cursor string becomes null, empty location is hidden', () {
      final page = CommentPage.fromV2({
        'cursor': 'normalHot#3',
        'comments': [
          {
            'commentId': 1,
            'content': 'x',
            'ipLocation': {'location': ''},
          },
        ],
      });
      expect(page.cursor, isNull);
      expect(page.comments.single.ipLocation, isNull);
      expect(page.comments.single.user.id, 0);
    });

    test('v1 page uses the last timestamp as cursor', () {
      final page = CommentPage.fromV1({
        'total': 10,
        'more': true,
        'hotComments': [
          {'commentId': 5, 'content': 'h'},
        ],
        'comments': [
          {'commentId': 1, 'content': 'a', 'time': 2000},
          {'commentId': 2, 'content': 'b', 'time': 1000},
        ],
      });
      expect(page.cursor, 1000);
      expect(page.hotComments, hasLength(1));
      expect(page.hasMore, isTrue);
    });
  });

  group('LyricPayload', () {
    test('reads every document and the embedded credits', () {
      final payload = LyricPayload.fromJson({
        'lrc': {
          'lyric':
              '{"t":0,"c":[{"tx":"作词: "},{"tx":"唐恬"}]}\n'
              '{"t":463,"c":[{"tx":"作曲: "},{"tx":"钱雷"},{"tx":"/"},{"tx":"X"}]}\n'
              '[00:22.290]都 是勇敢的',
        },
        'tlyric': {'lyric': '[00:22.290]all brave'},
        'romalrc': {'lyric': '[00:22.290]romaji'},
        'yrc': {'lyric': '[22290,1000](22290,500,0)都'},
        'ytlrc': {'lyric': '[22290]t'},
        'yromalrc': {'lyric': '[22290]r'},
        'klyric': {'lyric': ''},
        'transUser': {'nickname': 'translator'},
      });
      expect(payload.lrc, contains('都 是勇敢的'));
      expect(payload.translation, '[00:22.290]all brave');
      expect(payload.romaji, '[00:22.290]romaji');
      expect(payload.yrc, startsWith('[22290'));
      expect(payload.yrcTranslation, '[22290]t');
      expect(payload.yrcRomaji, '[22290]r');
      expect(payload.pureMusic, isFalse);
      expect(payload.hasTranslation, isTrue);
      expect(payload.translationUser, 'translator');
      expect(payload.credits.map((c) => c.role), ['作词', '作曲']);
      expect(payload.credits.last.names, ['钱雷', 'X']);
    });

    test('missing documents are null, pure music detected', () {
      final empty = LyricPayload.fromJson({'code': 200, 'nolyric': true});
      expect(empty.isEmpty, isTrue);
      expect(empty.uncollected, isTrue);
      expect(empty.translation, isNull);
      final pure = LyricPayload.fromJson({
        'lrc': {'lyric': '[99:00.00]纯音乐，请欣赏\n'},
      });
      expect(pure.pureMusic, isTrue);
      expect(LyricPayload.fromJson({'pureMusic': true}).pureMusic, isTrue);
    });
  });

  group('User', () {
    test('UserCollections splits liked / created / collected', () {
      const uid = 42;
      final playlists = Playlist.listFrom([
        {
          'id': 1,
          'name': 'X喜欢的音乐',
          'specialType': 5,
          'creator': {'userId': uid},
        },
        {
          'id': 2,
          'name': 'mine',
          'creator': {'userId': uid},
          'privacy': 10,
        },
        {
          'id': 3,
          'name': 'other',
          'subscribed': true,
          'creator': {'userId': 7},
        },
        {'id': 4, 'name': 'mine by userId', 'userId': uid},
      ]);
      final split = UserCollections.split(playlists, uid);
      expect(split.liked!.id, 1);
      expect(split.created.map((p) => p.id), [2, 4]);
      expect(split.created.first.isPrivate, isTrue);
      expect(split.collected.single.id, 3);
      expect(split.collected.single.subscribed, isTrue);
      expect(split.collected.single.isMine(uid), isFalse);
    });

    test('UserDetail reads level and counters', () {
      final detail = UserDetail.fromJson({
        'level': 10,
        'listenSongs': 35560,
        'createDays': 4461,
        'profile': {
          'userId': 32953014,
          'nickname': 'binaryify',
          'avatarUrl': 'a',
          'backgroundUrl': 'b',
          'signature': 'emmm',
          'vipType': 11,
          'follows': 22,
          'followeds': 94,
        },
      });
      expect(detail.id, 32953014);
      expect(detail.level, 10);
      expect(detail.listenSongs, 35560);
      expect(detail.follows, 22);
      expect(detail.followeds, 94);
      expect(detail.createDays, 4461);
      expect(detail.isVip, isTrue);
      expect(UserDetail.fromJson(const {}).nickname, '');
    });

    test('play record rows', () {
      final rows = parsePlayRecord([
        {
          'playCount': 12,
          'song': {'id': 1, 'name': 'a'},
        },
        {'playCount': 3},
      ]);
      expect(rows.single.song.id, 1);
      expect(rows.single.playCount, 12);
    });
  });

  group('Discovery', () {
    test('catalogue groups categories', () {
      final catalogue = PlaylistCatalogue.fromJson({
        'all': {'name': '全部歌单'},
        'categories': {'0': '语种', '1': '风格'},
        'sub': [
          {'name': '华语', 'category': 0, 'hot': true},
          {'name': '流行', 'category': 1, 'hot': true},
          {'name': '摇滚', 'category': 1, 'hot': false},
        ],
      });
      expect(catalogue.allName, '全部歌单');
      expect(catalogue.groups.map((g) => g.name), ['语种', '风格']);
      expect(catalogue.groups[1].categories.map((c) => c.name), ['流行', '摇滚']);
      expect(catalogue.hot.map((c) => c.name), ['华语', '流行']);
    });

    test('banners skip entries without an image', () {
      final banners = HomeBanner.listFrom([
        {'imageUrl': 'i', 'targetId': 5, 'targetType': 1, 'typeTitle': '新歌'},
        {'targetId': 6},
      ]);
      expect(banners.single.targetId, 5);
      expect(banners.single.title, '新歌');
    });

    test('suggestions and default keyword', () {
      final suggestions = SearchSuggestions.fromJson(
        {
          'songs': [
            {
              'id': 1,
              'name': 's',
              'artists': [
                {'id': 2, 'name': 'A'},
              ],
            },
          ],
          'artists': [
            {'id': 6452, 'name': '周杰伦'},
          ],
          'albums': [
            {'id': 3, 'name': 'al'},
          ],
        },
        keywords: ['周杰伦'],
      );
      expect(suggestions.keywords, ['周杰伦']);
      expect(suggestions.songs.single.artistText, 'A');
      expect(suggestions.artists.single.id, 6452);
      expect(suggestions.albums.single.id, 3);
      final keyword = DefaultSearchKeyword.fromJson({
        'data': {'showKeyword': '🔥Moments', 'realkeyword': 'Moments'},
      });
      expect(keyword.display, '🔥Moments');
      expect(keyword.keyword, 'Moments');
    });
  });

  group('Song', () {
    test('legacy FM shape and string numbers', () {
      final song = Song.fromJson({
        'id': '3449064757',
        'name': 'Housewife',
        'duration': 200000,
        'disc': '01',
        'no': 1,
        'artists': [
          {'id': 30784458, 'name': 'Tate McRae'},
        ],
        'album': {'id': 9, 'name': 'al', 'blurPicUrl': 'blur'},
      });
      expect(song.id, 3449064757);
      expect(song.cd, 1);
      expect(song.no, 1);
      expect(song.album.picUrl, 'blur');
    });

    test('toJson never persists a playability flag', () {
      final song = Song.fromJson(
        {'id': 1, 'name': 'x', 'st': -1},
        privilege: {'code': 404, 'maxBrLevel': 'lossless'},
      );
      final json = song.toJson();
      expect(json.containsKey('st'), isFalse);
      expect((json['privilege'] as Map).containsKey('code'), isFalse);
      expect(Song.fromJson(json).playable, isTrue);
    });

    test('privileges matched by id', () {
      final songs = Song.listWithPrivileges(
        [
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ],
        [
          {'id': 2, 'code': 404},
          {'id': 1, 'code': 200, 'maxBrLevel': 'hires'},
        ],
      );
      expect(songs[0].playable, isTrue);
      expect(songs[0].maxLevel, 'hires');
      expect(songs[1].playable, isFalse);
    });

    test('audio level fallback chain', () {
      expect(AudioLevel.lossless.fallbackChain, [
        AudioLevel.lossless,
        AudioLevel.exhigh,
        AudioLevel.higher,
        AudioLevel.standard,
      ]);
      expect(AudioLevel.jymaster.fallbackChain.first, AudioLevel.jymaster);
      expect(AudioLevel.jymaster.fallbackChain[1], AudioLevel.lossless);
      expect(AudioLevel.standard.fallbackChain, [AudioLevel.standard]);
    });
  });
}
