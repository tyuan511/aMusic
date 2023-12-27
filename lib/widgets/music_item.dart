import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/models/song.dart';
import "package:laji_music/extensions/duration.dart";
import 'package:laji_music/providers/user.dart';

class MusicItem extends HookConsumerWidget {
  final Song data;
  final bool isActive;
  final VoidCallback onPressed;

  const MusicItem({Key? key, required this.data, required this.isActive, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likeList = ref.watch(userProvider.select((value) => value.likeSongs));

    return InkWell(
      onTap: () {
        onPressed();
      },
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () {
                ref.read(userProvider.notifier).likeSong(data.id, !likeList.contains(data.id));
              },
              icon: Icon(Icons.favorite_rounded,
                  size: 20,
                  color: likeList.contains(data.id)
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary.withOpacity(0.1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data.name,
                style: Theme.of(context).textTheme.bodyLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 140,
              child: Text(
                data.author,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 60,
              child: Text(
                data.duration.formate(),
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
