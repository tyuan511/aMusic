import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:amusic/models/playlist.dart';
import 'package:amusic/providers/user.dart';
import 'package:amusic/utils/repo.dart';
import 'package:amusic/widgets/playlist_cover_item.dart';

class UserPlaylistScreen extends StatefulHookConsumerWidget {
  const UserPlaylistScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<UserPlaylistScreen> createState() => _UserPlaylistScreenState();
}

class _UserPlaylistScreenState extends ConsumerState<UserPlaylistScreen> {
  List<Playlist> myPlaylist = [];
  List<Playlist> recommandPlaylist = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();

    Future.wait([getMyPlaylist(), getRecommandList()]).then((value) {
      setState(() {
        loading = false;
      });
    });
  }

  Future<void> getMyPlaylist() async {
    final userID = ref.read(userProvider.select((value) => value.id));
    final res = await (await repo.userPlaylist(userID!)).asFuture;

    setState(() {
      myPlaylist = res.playlist.map((e) => Playlist(id: e.id, name: e.name, picUrl: e.coverImgUrl)).toList();
    });
  }

  Future<void> getRecommandList() async {
    final res = await (await repo.recommendPlaylist()).asFuture;

    setState(() {
      final list = res.recommend.map((e) => Playlist(id: e.id, name: e.name, picUrl: e.picUrl)).toList();
      recommandPlaylist = [
        Playlist(id: -1, name: '每日推荐歌曲', picUrl: 'https://s11.ax1x.com/2023/12/30/piO3P9H.jpg'),
        ...list
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("我的歌单", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: myPlaylist.length,
                    itemBuilder: (context, index) => PlaylistCoverItem(
                      data: myPlaylist[index],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('推荐歌单', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recommandPlaylist.length,
                    itemBuilder: (context, index) => PlaylistCoverItem(
                      data: recommandPlaylist[index],
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}
