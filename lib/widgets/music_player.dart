import 'package:flutter/material.dart';
import 'package:laji_music/widgets/image_cover.dart';

class MusicPlayer extends StatelessWidget {
  const MusicPlayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 72),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: const ImageCover(
              url: "https://p2.music.126.net/UAx4r7pN-53CNbiqQ4CcXQ==/109951166589723188.jpg",
              width: 200,
              height: 200,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "落在生命里的光",
            style: Theme.of(context).textTheme.titleMedium!.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '尹昔眠',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: 100,
              itemBuilder: (context, index) => Text(
                "这是一句歌词哈",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: index == 2
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text("00:00"),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: LinearProgressIndicator(
                      value: 0.2,
                    ),
                  ),
                ),
                Text("03:58"),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.skip_previous_rounded,
                    size: 32,
                  )),
              const SizedBox(width: 24),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    size: 48,
                  )),
              const SizedBox(width: 24),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    size: 32,
                  ))
            ],
          ),
          const SizedBox(height: 8)
        ],
      ),
    );
  }
}
