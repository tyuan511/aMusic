import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laji_music/widgets/menu_item.dart';
import 'package:laji_music/widgets/music_player.dart';

class HomeLayout extends StatelessWidget {
  final Widget child;

  const HomeLayout({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final path = GoRouter.of(context).routeInformationProvider.value.uri.path;

    return Scaffold(
      body: Stack(children: [
        Container(
            constraints: const BoxConstraints.expand(),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://p1.music.126.net/CPUizRsYP_k_Ae33s7UVBw==/109951167165596732.jpg',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 20,
                sigmaY: 20,
              ),
              child: Container(
                color: Colors.white.withOpacity(0.75),
              ),
            )),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(
                width: 1,
                color: Theme.of(context).dividerColor.withOpacity(0.2),
              ))),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        MenuItem(
                          path: '/user_playlist',
                          title: '歌单',
                          icon: Icons.headphones_rounded,
                          isActive: path == '/user_playlist',
                        ),
                        const SizedBox(height: 16),
                        MenuItem(
                          path: '/setting',
                          title: '设置',
                          icon: Icons.settings_rounded,
                          isActive: path == '/setting',
                        )
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 1),
                          borderRadius: BorderRadius.circular(26)),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.network(
                            "http://p1.music.126.net/K6NkXfZiDmRI_utJPXZG2g==/18525671418102343.jpg",
                          )),
                    ),
                    const SizedBox(height: 32)
                  ],
                ),
              ),
            ),
            Expanded(
              child: child,
            ),
            const SizedBox(
              width: 520,
              child: MusicPlayer(),
            )
          ],
        )
      ]),
    );
  }
}
