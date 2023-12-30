import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:amusic/consts/key.dart';
import 'package:amusic/layout/home.dart';
import 'package:amusic/providers/user.dart';
import 'package:amusic/screen/current_list.dart';
import 'package:amusic/screen/login.dart';
import 'package:amusic/screen/search.dart';
import 'package:amusic/screen/setting.dart';
import 'package:amusic/screen/song_list.dart';
import 'package:amusic/screen/splash.dart';
import 'package:amusic/screen/user_playlist.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@riverpod
GoRouter router(RouterRef ref) {
  final isAuth = ValueNotifier<bool>(false);
  ref
    ..onDispose(isAuth.dispose)
    ..listen(
      userProvider.select((value) => value.id != null),
      (_, next) {
        isAuth.value = next;
      },
    );

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/splash',
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) => HomeLayout(
          child: child,
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/user_playlist',
              builder: (context, state) => const UserPlaylistScreen(),
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/setting',
              builder: (context, state) => SettingScreen(),
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/song_list',
              builder: (context, state) => SongListScreen(
                key: Key(state.extra.toString()),
                playlistID: state.extra as int,
              ),
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/current_list',
              builder: (context, state) => const CurrentList(),
            )
          ]),
        ],
      )
    ],
    refreshListenable: isAuth,
    redirect: (context, state) {
      if (state.fullPath == '/splash') return null;

      if (state.fullPath != '/login' && !isAuth.value) {
        return '/login';
      }
      if (state.fullPath == '/login' && isAuth.value) {
        return '/user_playlist';
      }
      return null;
    },
  );
}

extension GoRouterExtension on GoRouter {
  String get location {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList =
        lastMatch is ImperativeRouteMatch ? lastMatch.matches : routerDelegate.currentConfiguration;
    final String location = matchList.uri.toString();
    return location;
  }
}
