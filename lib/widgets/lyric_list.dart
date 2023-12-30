import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:amusic/models/lyric.dart';

class LyricList extends HookConsumerWidget {
  final List<LyricRow>? lyricList;
  final Duration? position;

  const LyricList({Key? key, required this.lyricList, required this.position}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = useState(0);
    final scrollController = useScrollController();

    useEffect(() {
      if (lyricList == null) return;
      var idx = lyricList!.indexWhere((element) => element.time > (position ?? Duration.zero));
      if (idx < 0) idx = lyricList!.length;
      index.value = idx - 1;

      return null;
    }, [position]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = min(index.value * 30, scrollController.position.maxScrollExtent).toDouble();
      scrollController.animateTo(
        pos,
        curve: Curves.linear,
        duration: const Duration(milliseconds: 100),
      );
    });

    return Expanded(
      child: ListView.builder(
        controller: scrollController,
        itemCount: lyricList?.length ?? 0,
        itemBuilder: (context, i) => SizedBox(
          height: 30,
          child: Text(
            lyricList?[i].text ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: i == index.value
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
}
