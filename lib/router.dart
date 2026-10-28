import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/playlist.dart';
import 'services/app.dart';
import 'theme/app_theme.dart';
import 'ui/album/album_page.dart';
import 'ui/artist/artist_albums_page.dart';
import 'ui/artist/artist_page.dart';
import 'ui/artist/artist_songs_page.dart';
import 'ui/charts/charts_page.dart';
import 'ui/home/home_page.dart';
import 'ui/library/history_page.dart';
import 'ui/library/library_page.dart';
import 'ui/local/local_music_page.dart';
import 'ui/player/now_playing_page.dart';
import 'ui/player/player_transition.dart';
import 'ui/playlist/playlist_page.dart';
import 'ui/search/search_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/shell.dart';
import 'ui/splash/splash_page.dart';
import 'ui/widgets/kit.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Root locations of the shell branches, in navigation order. Must match
/// `navDestinations` in `ui/widgets/sidebar.dart`.
const List<String> shellDestinations = [
  '/home',
  '/charts',
  '/search',
  '/library',
  '/settings',
];

/// Which panel the now playing screen opens on.
enum PlayerPanel {
  cover,
  lyrics,
  queue,
  comments;

  static PlayerPanel fromName(String? name) => PlayerPanel.values.firstWhere(
    (panel) => panel.name == name,
    orElse: () => PlayerPanel.cover,
  );
}

/// Detail pages reachable from every branch. They are nested under each branch
/// root so the shell (sidebar / floating navigation) stays visible and the
/// back stack stays per tab.
List<RouteBase> _detailRoutes() => [
  GoRoute(
    path: 'playlist/:id',
    builder: (context, state) {
      final id = _id(state);
      final extra = state.extra;
      return PlaylistPage(
        key: ValueKey('playlist-$id'),
        playlistId: id,
        preview: extra is Playlist ? extra : null,
      );
    },
  ),
  GoRoute(
    path: 'album/:id',
    builder: (context, state) => AlbumPage(
      key: ValueKey('album-${_id(state)}'),
      albumId: _id(state),
      preview: state.extra,
    ),
  ),
  GoRoute(
    path: 'artist/:id',
    builder: (context, state) => ArtistPage(
      key: ValueKey('artist-${_id(state)}'),
      artistId: _id(state),
      preview: state.extra,
    ),
    routes: [
      GoRoute(
        path: 'songs',
        builder: (context, state) => ArtistSongsPage(artistId: _id(state)),
      ),
      GoRoute(
        path: 'albums',
        builder: (context, state) => ArtistAlbumsPage(artistId: _id(state)),
      ),
    ],
  ),
  GoRoute(path: 'local', builder: (context, state) => const LocalMusicPage()),
  GoRoute(path: 'history', builder: (context, state) => const HistoryPage()),
];

int _id(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

GoRouter createRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: kDebugMode,
    refreshListenable: Listenable.merge([
      app.bootstrapped,
      app.session,
      app.session.authRevision,
    ]),
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (!app.bootstrapped.value) {
        return path == '/splash' ? null : '/splash';
      }
      if (path == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            ShellBranchSwitcher(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/charts',
                builder: (context, state) => const ChartsPage(),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) =>
                    SearchPage(initialKeyword: state.uri.queryParameters['q']),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryPage(),
                routes: _detailRoutes(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
                routes: _detailRoutes(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: NowPlayingPage(
            panel: PlayerPanel.fromName(state.uri.queryParameters['panel']),
          ),
          transitionDuration: PlayerMotion.open,
          reverseTransitionDuration: PlayerMotion.close,
          // Grows out of the mini player bar; the cover flies along as a hero.
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              PlayerRouteTransition(animation: animation, child: child),
        ),
      ),
    ],
    errorBuilder: (context, state) =>
        _NotFoundPage(location: state.uri.toString()),
  );
}

// ------------------------------------------------------------- navigation

/// Root of the branch the user is currently in (`/home`, `/search` ...), so a
/// detail page opens inside the active tab instead of jumping to another.
String _branchRoot(BuildContext context) {
  String location;
  try {
    location = GoRouterState.of(context).matchedLocation;
  } on Object {
    location = '/home';
  }
  for (final root in shellDestinations) {
    if (location == root || location.startsWith('$root/')) return root;
  }
  return '/home';
}

void openPlaylist(BuildContext context, Playlist playlist) => context.push(
  '${_branchRoot(context)}/playlist/${playlist.id}',
  extra: playlist,
);

void openPlaylistById(BuildContext context, int id) =>
    context.push('${_branchRoot(context)}/playlist/$id');

void openDailyRecommend(BuildContext context) => context.push(
  '${_branchRoot(context)}/playlist/${Playlist.dailyRecommendId}',
);

/// [preview] may be any summary model the album page understands.
void openAlbum(BuildContext context, int id, {Object? preview}) {
  if (id <= 0) return;
  context.push('${_branchRoot(context)}/album/$id', extra: preview);
}

void openArtist(BuildContext context, int id, {Object? preview}) {
  if (id <= 0) return;
  context.push('${_branchRoot(context)}/artist/$id', extra: preview);
}

void openArtistSongs(BuildContext context, int id) =>
    context.push('${_branchRoot(context)}/artist/$id/songs');

void openArtistAlbums(BuildContext context, int id) =>
    context.push('${_branchRoot(context)}/artist/$id/albums');

void openLocalMusic(BuildContext context) =>
    context.push('${_branchRoot(context)}/local');

void openHistory(BuildContext context) =>
    context.push('${_branchRoot(context)}/history');

/// Switches to the search tab, optionally searching [keyword] right away.
void openSearch(BuildContext context, {String? keyword}) {
  final query = keyword == null || keyword.isEmpty
      ? ''
      : '?q=${Uri.encodeQueryComponent(keyword)}';
  context.go('/search$query');
}

/// Opens the now playing screen. [queue] is kept for older call sites.
void openPlayer(
  BuildContext context, {
  bool queue = false,
  PlayerPanel? panel,
}) {
  final target = panel ?? (queue ? PlayerPanel.queue : null);
  context.push(target == null ? '/player' : '/player?panel=${target.name}');
}

/// The same, for code without a widget context (keyboard shortcuts).
void openPlayerGlobal({PlayerPanel? panel}) {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;
  openPlayer(context, panel: panel);
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const PageHeader(title: '页面不存在'),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.explore_off_rounded,
                      size: 56,
                      color: context.surfaces.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(location, style: context.text.bodyMedium),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('回到首页'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
