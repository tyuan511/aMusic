import 'package:go_router/go_router.dart';
import 'package:laji_music/consts/key.dart';
import 'package:laji_music/layout/home.dart';
import 'package:laji_music/models/playlist.dart';
import 'package:laji_music/screen/setting.dart';
import 'package:laji_music/screen/song_list.dart';
import 'package:laji_music/screen/user_playlist.dart';

// GoRouter configuration
final router = GoRouter(
  initialLocation: '/user_playlist',
  navigatorKey: rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => HomeLayout(
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/user_playlist',
          builder: (context, state) => const UserPlaylistScreen(),
        ),
        GoRoute(
          path: '/setting',
          builder: (context, state) => const SettingScreen(),
        ),
        GoRoute(
          path: '/song_list',
          builder: (context, state) => SongListScreen(playlist: state.extra as Playlist?),
        )
      ],
    )
  ],
);
