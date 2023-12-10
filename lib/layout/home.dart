import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/providers/router.dart';
import 'package:laji_music/widgets/image_cover.dart';
import 'package:laji_music/widgets/menu_item.dart';
import 'package:laji_music/widgets/music_player.dart';

class HomeLayout extends HookConsumerWidget {
  final Widget child;

  const HomeLayout({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(routerProvider.select((value) => value.location));

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 1),
                        borderRadius: BorderRadius.circular(40)),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: const ImageCover(
                          url: "http://p1.music.126.net/K6NkXfZiDmRI_utJPXZG2g==/18525671418102343.jpg",
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
            width: 420,
            child: MusicPlayer(),
          )
        ],
      ),
    );
  }
}
