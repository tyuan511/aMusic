import 'package:amusic/models/comment_target.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/router.dart';
import 'package:amusic/services/app.dart';
import 'package:amusic/services/player_service.dart';
import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/player/lyrics_view.dart';
import 'package:amusic/ui/player/now_playing_page.dart';
import 'package:amusic/ui/player/player_panel_controller.dart';
import 'package:amusic/ui/player/player_sheets.dart';
import 'package:amusic/ui/player/player_transition.dart';
import 'package:amusic/ui/player/queue_view.dart';
import 'package:amusic/ui/shared/comments_view.dart';
import 'package:amusic/ui/widgets/mini_player.dart';
import 'package:amusic/ui/widgets/seek_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _songs = [
  Song(
    id: 1,
    name: '晴天',
    artists: [Artist(id: 6452, name: '周杰伦')],
    album: AlbumRef(id: 18905, name: '叶惠美'),
    duration: Duration(minutes: 4, seconds: 29),
  ),
  Song(
    id: 2,
    name: '七里香',
    artists: [Artist(id: 6452, name: '周杰伦')],
    album: AlbumRef(id: 18903, name: '七里香'),
    duration: Duration(minutes: 4, seconds: 59),
  ),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('labels', () {
    test('speedLabel trims trailing zeros', () {
      expect(speedLabel(1), '1x');
      expect(speedLabel(1.5), '1.5x');
      expect(speedLabel(0.75), '0.75x');
      expect(speedLabel(2), '2x');
    });

    test('remainingLabel', () {
      expect(remainingLabel(const Duration(minutes: 2, seconds: 15)), '-2:15');
      expect(remainingLabel(const Duration(seconds: -3)), '-0:00');
    });

    test('sleepLabel', () {
      expect(sleepLabel(Duration.zero), '本首结束');
      expect(sleepLabel(const Duration(minutes: 23, seconds: 41)), '23:41');
    });

    test('relativeCommentTime', () {
      final now = DateTime(2024, 6, 12, 15, 30);
      String rel(DateTime t) => relativeCommentTime(t, now: now);
      expect(rel(now.subtract(const Duration(seconds: 20))), '刚刚');
      expect(rel(now.subtract(const Duration(minutes: 5))), '5分钟前');
      expect(rel(now.subtract(const Duration(hours: 3))), '3小时前');
      expect(rel(DateTime(2024, 6, 11, 9, 5)), '昨天 09:05');
      expect(rel(DateTime(2024, 6, 9, 9, 5)), '3天前');
      expect(rel(DateTime(2024, 3, 2)), '03-02');
      expect(rel(DateTime(2021, 3, 2)), '2021-03-02');
      expect(relativeCommentTime(null, fallback: '昨天'), '昨天');
    });
  });

  group('PlayerPanelController', () {
    test('toggles the visible panel back to the cover', () {
      final controller = PlayerPanelController.instance;
      var visible = PlayerPanel.lyrics;
      controller
        ..isOpen.value = true
        ..visibleResolver = () => visible;
      addTearDown(() {
        controller
          ..isOpen.value = false
          ..visibleResolver = null
          ..request.value = null;
      });
      showPlayerPanel(PlayerPanel.lyrics);
      expect(controller.request.value, PlayerPanel.cover);
      visible = PlayerPanel.cover;
      showPlayerPanel(PlayerPanel.queue);
      expect(controller.request.value, PlayerPanel.queue);
    });
  });

  group('widgets', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      app = await AppServices.bootstrap();
    });

    tearDown(() {
      app.player.queue.value = const PlayQueue();
      app.player.currentSongId.value = null;
    });

    void fill() {
      app.player.queue.value = const PlayQueue(
        songs: _songs,
        sourceTitle: '测试歌单',
      );
      app.player.currentSongId.value = _songs.first.id;
    }

    for (final size in const [Size(400, 860), Size(1440, 900)]) {
      final label = '@${size.width.toInt()}';

      for (final filled in [false, true]) {
        final state = filled ? 'playing' : 'empty';
        testWidgets('NowPlayingPage $state $label', (tester) async {
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          if (filled) fill();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.build(Brightness.dark),
              home: const NowPlayingPage(panel: PlayerPanel.lyrics),
            ),
          );
          await _settle(tester);
          expect(tester.takeException(), isNull);
          if (filled) {
            expect(find.text('晴天'), findsWidgets);
          } else {
            expect(find.text('选首歌开始吧'), findsWidgets);
          }
          await _unmount(tester);
        });

        testWidgets('MiniPlayer $state $label', (tester) async {
          tester.view
            ..physicalSize = size
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          if (filled) fill();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.build(Brightness.dark),
              home: const Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: MiniPlayer(),
                ),
              ),
            ),
          );
          await _settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.text(filled ? '晴天' : '选首歌开始吧'), findsOneWidget);
          await _unmount(tester);
        });
      }
    }

    for (final size in const [Size(400, 860), Size(1440, 900)]) {
      testWidgets('mini player ⇄ player transition flies the cover '
          '@${size.width.toInt()}', (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        app.player.queue.value = PlayQueue(
          songs: [
            _songs.first.copyWith(
              album: const AlbumRef(
                id: 18905,
                name: '叶惠美',
                picUrl: 'https://example.com/cover.jpg',
              ),
            ),
          ],
        );
        app.player.currentSongId.value = _songs.first.id;
        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: nav,
            theme: AppTheme.build(Brightness.dark),
            home: const Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: MiniPlayer(),
              ),
            ),
          ),
        );
        await _settle(tester);
        final heroes = find.byType(NowPlayingCoverHero);
        expect(heroes, findsOneWidget);

        nav.currentState!.push(
          PageRouteBuilder<void>(
            transitionDuration: PlayerMotion.open,
            reverseTransitionDuration: PlayerMotion.close,
            pageBuilder: (_, _, _) => const NowPlayingPage(),
            transitionsBuilder: (_, animation, _, child) =>
                PlayerRouteTransition(animation: animation, child: child),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        // Mid flight: the shared cover is in the overlay, both ends hidden.
        expect(find.byType(Hero), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await _settle(tester);
        expect(find.byType(CircularCover), findsOneWidget);

        nav.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        expect(tester.takeException(), isNull);
        await _settle(tester);
        expect(find.byType(CircularCover), findsNothing);
        expect(heroes, findsOneWidget);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    }

    testWidgets('compact cover tap swaps to lyrics and panel requests switch '
        'back', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 860)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      fill();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.dark),
          home: const NowPlayingPage(),
        ),
      );
      await _settle(tester);
      expect(find.byType(LyricsPanel), findsNothing);
      await tester.tap(find.byType(CircularCover));
      await _settle(tester);
      expect(find.byType(LyricsPanel), findsOneWidget);
      expect(PlayerPanelController.instance.visible, PlayerPanel.lyrics);
      // Asking for the visible panel again toggles back to the cover.
      showPlayerPanel(PlayerPanel.lyrics);
      await _settle(tester);
      expect(find.byType(LyricsPanel), findsNothing);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
      expect(PlayerPanelController.instance.isOpen.value, isFalse);
    });

    testWidgets('QueueView lists the queue', (tester) async {
      fill();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.dark),
          home: const Scaffold(body: QueueView()),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('七里香'), findsWidgets);
      expect(find.textContaining('2 首'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('CommentsView shows an error state offline', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.dark),
          home: const Scaffold(
            body: CommentsView(
              target: CommentTarget(CommentResource.song, 1, title: '晴天'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('热门'), findsOneWidget);
      expect(find.text('最新'), findsOneWidget);
      await tester.tap(find.text('最新'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });
}
