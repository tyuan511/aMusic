import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/extensions/duration.dart';
import 'package:laji_music/providers/player.dart';
import 'package:laji_music/widgets/image_cover.dart';
import 'package:laji_music/widgets/lyric_list.dart';

class MusicPlayer extends HookConsumerWidget {
  const MusicPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    useEffect(() {
      ref.read(playerProvider.notifier).init();

      return null;
    }, []);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 72),
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: ImageCover(
              url: player.currSong?.picUrl,
              width: 200,
              height: 200,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            player.currSong?.name ?? '暂无歌曲播放',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            player.currSong?.author ?? '',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          LyricList(
            key: ValueKey(player.currSong?.id),
            lyricList: player.lyric,
            position: player.position,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(player.position.formate()),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: LinearProgressIndicator(
                      value:
                          player.currSong == null ? 0 : player.position.inSeconds / player.currSong!.duration.inSeconds,
                    ),
                  ),
                ),
                Text(player.currSong?.duration.formate() ?? '00:00'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: () {
                    ref.read(playerProvider.notifier).prev();
                  },
                  icon: const Icon(
                    Icons.skip_previous_rounded,
                    size: 32,
                  )),
              const SizedBox(width: 24),
              IconButton(
                onPressed: () {
                  ref.read(playerProvider.notifier).playOrPause();
                },
                icon: player.songLoading
                    ? const SizedBox(
                        height: 48,
                        width: 48,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : player.isPlaying
                        ? const Icon(Icons.pause_rounded, size: 48)
                        : const Icon(
                            Icons.play_arrow_rounded,
                            size: 48,
                          ),
              ),
              const SizedBox(width: 24),
              IconButton(
                  onPressed: () {
                    ref.read(playerProvider.notifier).next();
                  },
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    size: 32,
                  ))
            ],
          ),
          const SizedBox(height: 12)
        ],
      ),
    );
  }
}
