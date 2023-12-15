import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/models/playlist.dart';
import 'package:laji_music/providers/user.dart';
import 'package:laji_music/utils/repo.dart';
import 'package:laji_music/widgets/playlist_cover_item.dart';

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
    final res = await (await repo.personalizedPlaylist()).asFuture;

    setState(() {
      recommandPlaylist = res.result.map((e) => Playlist(id: e.id, name: e.name, picUrl: e.picUrl)).toList();
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
