import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laji_music/consts/key.dart';
import 'package:laji_music/layout/home.dart';
import 'package:laji_music/models/playlist.dart';
import 'package:laji_music/providers/user.dart';
import 'package:laji_music/screen/login.dart';
import 'package:laji_music/screen/setting.dart';
import 'package:laji_music/screen/song_list.dart';
import 'package:laji_music/screen/splash.dart';
import 'package:laji_music/screen/user_playlist.dart';
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
            builder: (context, state) => SettingScreen(),
          ),
          GoRoute(
            path: '/song_list',
            builder: (context, state) => SongListScreen(playlist: state.extra as Playlist?),
          )
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
