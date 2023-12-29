import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/models/song.dart';
import 'package:laji_music/providers/player.dart';
import 'package:laji_music/utils/repo.dart';
import 'package:laji_music/widgets/music_item.dart';
import 'package:ncm_api/netease_api.dart';

class SearchScreen extends StatefulHookConsumerWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  List<String> hotWords = [];
  final _controller = TextEditingController();
  List<Song> songs = [];
  bool loading = false;

  @override
  void initState() {
    getHotWords();
    super.initState();
  }

  getHotWords() async {
    final res = await (await repo.searchHotWords()).asFuture;
    setState(() {
      hotWords = res;
    });
  }

  search(String keyword) async {
    setState(() {
      loading = true;
    });
    final res = await (await repo.search(keyword, SearchType.song)).asFuture;
    setState(() {
      loading = false;
      songs = (res['result']['songs'] as List)
          .map(
            (e) => Song(
              id: e['id'],
              name: e['name'],
              picUrl: e['al']['picUrl'],
              duration: Duration(milliseconds: e['dt']),
              album: e['al']['name'],
              author: e['ar'].map((e) => e['name']).join(' '),
            ),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currSong = ref.watch(playerProvider.select((value) => value.currSong));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    search(_controller.text);
                  },
                  child: const Text("搜索"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              children: hotWords
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          _controller.text = e;
                          search(e);
                        },
                        child: Chip(
                          label: Text(e),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: songs.length,
                      itemBuilder: (context, index) => MusicItem(
                        data: songs[index],
                        isActive: currSong?.id == songs[index].id,
                        onPressed: () {
                          ref.read(playerProvider.notifier).playSongs(songs, index: index);
                        },
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }
}
