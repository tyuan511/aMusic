import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:amusic/extensions/datetime.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/providers/player.dart';
import 'package:amusic/utils/repo.dart';
import 'package:amusic/widgets/image_cover.dart';
import 'package:amusic/widgets/music_item.dart';
import 'package:ncm_api/netease_api.dart';

class SongListScreen extends StatefulHookConsumerWidget {
  final int? playlistID;

  const SongListScreen({Key? key, this.playlistID}) : super(key: key);

  @override
  ConsumerState<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends ConsumerState<SongListScreen> {
  List<Song> songs = [];
  Playlist? playlist;
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    getDetail();
  }

  getDetail() async {
    if (widget.playlistID == null) return;

    if (widget.playlistID == -1) {
      final res = await (await repo.recommendSongs()).asFuture;

      setState(() {
        playlist = Playlist(
          tags: [],
          subscribers: [],
          creator: Creator(nickname: 'aMusic', avatarUrl: 'https://s11.ax1x.com/2023/12/30/piO3u4g.jpg'),
          tracks: [],
          trackIds: [],
          name: '每日歌曲推荐',
          coverImgUrl: 'https://s11.ax1x.com/2023/12/30/piO3P9H.jpg',
          createTime: DateTime.now().millisecondsSinceEpoch,
        );
        songs = res.dailySongs
            .map(
              (s) => Song(
                id: s.id,
                name: s.name,
                duration: Duration(milliseconds: s.duration),
                author: (s.artists).map((e) => e.name).join(' '),
                album: s.album.name,
                picUrl: s.album.picUrl,
              ),
            )
            .toList();
      });
    } else {
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
      });
    }
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
      if (idx >= 0) {
        final pos = min(idx * 56, scrollController.position.maxScrollExtent).toDouble();
        scrollController.animateTo(pos, curve: Curves.linear, duration: const Duration(milliseconds: 500));
      }
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
                              Text("共${songs.length}首歌", style: Theme.of(context).textTheme.bodyMedium),
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
