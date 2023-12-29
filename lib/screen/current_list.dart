import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/providers/player.dart';
import 'package:laji_music/widgets/music_item.dart';

class CurrentList extends HookConsumerWidget {
  const CurrentList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currList = ref.watch(playerProvider.select((value) => value.songList));
    final scrollController = useScrollController();

    final currSong = ref.watch(playerProvider.select((value) => value.currSong));

    if (currSong != null && currList != null && scrollController.hasClients) {
      final idx = currList.indexWhere((element) => element.id == currSong.id);
      if (idx >= 0) {
        final pos = min(idx * 56, scrollController.position.maxScrollExtent).toDouble();
        scrollController.animateTo(pos, curve: Curves.linear, duration: const Duration(milliseconds: 500));
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 32, left: 24, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "当前播放列表",
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: (currList ?? []).length,
                itemBuilder: (context, index) => MusicItem(
                    data: (currList ?? [])[index],
                    isActive: currSong?.id == (currList ?? [])[index].id,
                    onPressed: () {
                      ref.read(playerProvider.notifier).playSongs((currList ?? []), index: index);
                    }),
              ),
            )
          ],
        ),
      ),
    );
  }
}
