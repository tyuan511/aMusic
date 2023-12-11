import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/models/lyric.dart';

class LyricList extends HookConsumerWidget {
  final List<LyricRow>? lyricList;
  final int? index;

  const LyricList({Key? key, required this.lyricList, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();

    useEffect(() {
      if (lyricList == null) {
        return;
      }

      final pos = min((index! - 1) * 30, scrollController.position.maxScrollExtent).toDouble();
      scrollController.jumpTo(pos);
      return null;
    }, [index]);

    return Expanded(
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: lyricList?.length ?? 0,
        itemBuilder: (context, i) => SizedBox(
          height: 30,
          child: Text(
            lyricList?[i].text ?? '',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: i == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
}
