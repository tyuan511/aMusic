import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laji_music/widgets/image_cover.dart';
import 'package:laji_music/widgets/music_player.dart';

class HomeLayout extends StatefulWidget {
  final Widget child;

  const HomeLayout({Key? key, required this.child}) : super(key: key);

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  int _idx = 0;
  final tabs = [
    {"text": "歌单", "icon": Icons.headphones_rounded, "location": "/user_playlist"},
    {"text": "设置", "icon": Icons.settings_rounded, "location": "/setting"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NavigationRail(
            selectedIndex: _idx,
            onDestinationSelected: (int index) {
              setState(() {
                _idx = index;
                context.go(tabs[_idx]['location'] as String);
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: tabs
                .map((tab) =>
                    NavigationRailDestination(icon: Icon(tab['icon'] as IconData), label: Text(tab['text'] as String)))
                .toList(),
            trailing: Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
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
                ),
              ),
            ),
          ),
          VerticalDivider(thickness: 1, width: 1, color: Theme.of(context).dividerColor.withOpacity(0.2)),
          Expanded(
            child: widget.child,
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
