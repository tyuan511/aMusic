import 'package:flutter/material.dart';
import 'package:laji_music/mock/recommand_list_data.dart';
import 'package:laji_music/widgets/playlist_cover_item.dart';

class UserPlaylistScreen extends StatelessWidget {
  const UserPlaylistScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
              itemCount: recommandListData.length,
              itemBuilder: (context, index) => PlaylistCoverItem(
                data: recommandListData[index],
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
              itemCount: recommandListData.length,
              itemBuilder: (context, index) => PlaylistCoverItem(
                data: recommandListData[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
