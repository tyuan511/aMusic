import 'package:flutter/material.dart';
import 'package:laji_music/mock/song_list_data.dart';
import 'package:laji_music/models/playlist.dart';
import 'package:laji_music/widgets/image_cover.dart';
import 'package:laji_music/widgets/music_item.dart';

class SongListScreen extends StatelessWidget {
  final Playlist? playlist;

  const SongListScreen({Key? key, this.playlist}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (playlist == null) {
      return const Center(
        child: Text('歌单不存在'),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 32, left: 24, right: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImageCover(
                    url: playlist!.picUrl,
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
                              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 1),
                              borderRadius: BorderRadius.circular(20)),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: const ImageCover(
                                url: "http://p1.music.126.net/K6NkXfZiDmRI_utJPXZG2g==/18525671418102343.jpg",
                              )),
                        ),
                        const SizedBox(width: 8),
                        Text('Tangge丶', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(width: 12),
                        Text('2022-08-19创建', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                            onPressed: () {},
                            child: const Row(
                              children: [
                                Icon(Icons.play_arrow_rounded),
                                SizedBox(width: 4),
                                Text("播放全部"),
                              ],
                            )),
                        const SizedBox(width: 12),
                        Text("共80首歌曲", style: Theme.of(context).textTheme.bodyMedium),
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
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
          itemCount: songListData.length,
          itemBuilder: (context, index) => MusicItem(data: songListData[index]),
        ),
      )
    ]);
  }
}
