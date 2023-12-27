import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/extensions/datetime.dart';
import 'package:laji_music/models/song.dart';
import 'package:laji_music/providers/player.dart';
import 'package:laji_music/utils/repo.dart';
import 'package:laji_music/widgets/image_cover.dart';
import 'package:laji_music/widgets/music_item.dart';
import 'package:ncm_api/netease_api.dart';

class SongListScreen extends StatefulHookConsumerWidget {
  final int? playlistID;

  const SongListScreen({Key? key, this.playlistID}) : super(key: key);

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  List<Song> songs = [];
  List<GlobalKey> keys = [];
  Playlist? playlist;
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    getDetail();
  }

  getDetail() async {
    if (widget.playlistID == null) return;

    final res = await (await repo.playlistDetail(widget.playlistID!)).asFuture;

    setState(() {
      playlist = res.playlist;

      songs = res.playlist.tracks
          .map(
            (s) => Song(
              id: s.id,
              name: s.name,
              duration: Duration(milliseconds: s.dt),
              author: (s.ar).map((e) => e.name).join(' '),
              album: s.al.name,
              picUrl: s.al.picUrl,
            ),
          )
          .toList();
      keys = List.generate(songs.length, (index) => GlobalKey());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.playlistID == null) {
      return const Center(
        child: Text('歌单不存在'),
      );
    }

    final currSong = ref.watch(playerProvider.select((value) => value.currSong));

    if (currSong != null && scrollController.hasClients) {
      final idx = songs.indexWhere((element) => element.id == currSong.id);
      final pos = min(idx * 56, scrollController.position.maxScrollExtent).toDouble();
      scrollController.animateTo(pos, curve: Curves.linear, duration: const Duration(milliseconds: 500));
    }

    return playlist == null
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 32, left: 24, right: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ImageCover(
                          url: '${playlist!.coverImgUrl}?param=160y160',
                          width: 160,
                          height: 160,
                        )),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist!.name,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 1),
                                    borderRadius: BorderRadius.circular(20)),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: ImageCover(
                                      url: playlist!.creator.avatarUrl,
                                    )),
                              ),
                              const SizedBox(width: 8),
                              Text(playlist!.creator.nickname, style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(width: 12),
                              Text('${playlist!.createTime.toDateTime().formate()}创建',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton(
                                  onPressed: () {
                                    ref.read(playerProvider.notifier).playSongs(songs);
                                  },
                                  child: const Row(
                                    children: [
                                      Icon(Icons.play_arrow_rounded),
                                      SizedBox(width: 4),
                                      Text("播放全部"),
                                    ],
                                  )),
                              const SizedBox(width: 12),
                              Text("共${playlist!.trackCount}首歌", style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
                itemCount: songs.length,
                itemBuilder: (context, index) => MusicItem(
                    key: keys[index],
                    data: songs[index],
                    isActive: currSong?.id == songs[index].id,
                    onPressed: () {
                      ref.read(playerProvider.notifier).playSongs(songs, index: index);
                    }),
              ),
            )
          ]);
  }
}
