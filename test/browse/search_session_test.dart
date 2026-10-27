import 'dart:async';

import 'package:amusic/models/paged.dart';
import 'package:amusic/models/search.dart';
import 'package:amusic/ui/browse_widgets/paged.dart';
import 'package:amusic/ui/search/search_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchSession', () {
    late List<String> calls;
    late SearchSession session;

    setUp(() {
      calls = [];
      session = SearchSession(
        pageSize: 2,
        fetcher: (tab, keyword, offset, limit) async {
          calls.add('${tab.name}:$keyword:$offset');
          return PagedList<Object>(
            items: [
              '$keyword-${tab.name}-$offset',
              '$keyword-${tab.name}-${offset + 1}',
            ],
            total: 5,
            hasMore: offset + limit < 5,
          );
        },
      );
    });

    tearDown(() => session.dispose());

    test('each tab fetches once and stays cached while switching', () async {
      session.setKeyword('晴天');
      final songs = session.controllerFor(SearchTab.songs);
      await pumpEventQueue();
      expect(songs.items, hasLength(2));

      final albums = session.controllerFor(SearchTab.albums);
      await pumpEventQueue();
      expect(albums.items, hasLength(2));

      // Back to songs: same controller, no new request.
      expect(identical(session.controllerFor(SearchTab.songs), songs), isTrue);
      expect(session.isCached(SearchTab.songs), isTrue);
      expect(session.isCached(SearchTab.artists), isFalse);
      expect(calls, ['songs:晴天:0', 'albums:晴天:0']);
    });

    test('paging appends and stops at the end', () async {
      session.setKeyword('a');
      final songs = session.controllerFor(SearchTab.songs);
      await pumpEventQueue();
      await songs.loadMore();
      await songs.loadMore();
      expect(songs.items, hasLength(6));
      expect(songs.hasMore, isFalse);
      await songs.loadMore();
      expect(calls, ['songs:a:0', 'songs:a:2', 'songs:a:4']);
    });

    test('a new keyword drops every cached tab', () async {
      session.setKeyword('a');
      session.controllerFor(SearchTab.songs);
      session.controllerFor(SearchTab.playlists);
      await pumpEventQueue();
      expect(session.setKeyword(' a '), isFalse);
      expect(session.setKeyword('b'), isTrue);
      expect(session.isCached(SearchTab.songs), isFalse);
      final songs = session.controllerFor(SearchTab.songs);
      await pumpEventQueue();
      expect(songs.items.first, 'b-songs-0');
    });
  });

  group('PagedController', () {
    test('refresh drops a stale in-flight page', () async {
      final pending = <Completer<PagedList<int>>>[];
      final controller = PagedController<int>((offset, limit) {
        final completer = Completer<PagedList<int>>();
        pending.add(completer);
        return completer.future;
      });
      unawaited(controller.loadMore());
      unawaited(controller.refresh());
      pending[1].complete(const PagedList(items: [2], total: 1));
      pending[0].complete(const PagedList(items: [1], total: 1));
      await pumpEventQueue();
      expect(controller.items, [2]);
      controller.dispose();
    });

    test('errors are kept and retried', () async {
      var fail = true;
      final controller = PagedController<int>((offset, limit) async {
        if (fail) throw Exception('boom');
        return const PagedList(items: [1], total: 1);
      });
      await controller.loadMore();
      expect(controller.errorText, 'boom');
      fail = false;
      await controller.loadMore();
      expect(controller.errorText, isNull);
      expect(controller.items, [1]);
      controller.dispose();
    });
  });

  group('SuggestionDebouncer', () {
    testWidgets('debounces and drops stale responses', (tester) async {
      final requests = <String>[];
      final completers = <String, Completer<SearchSuggestions>>{};
      final debouncer = SuggestionDebouncer(
        fetch: (keyword) {
          requests.add(keyword);
          return (completers[keyword] = Completer()).future;
        },
      );

      debouncer.update('j');
      await tester.pump(const Duration(milliseconds: 100));
      debouncer.update('ja');
      await tester.pump(const Duration(milliseconds: 100));
      expect(requests, isEmpty);
      await tester.pump(const Duration(milliseconds: 260));
      expect(requests, ['ja']);

      // A newer query is typed before 'ja' answers.
      debouncer.update('jay');
      await tester.pump(const Duration(milliseconds: 260));
      expect(requests, ['ja', 'jay']);
      completers['jay']!.complete(const SearchSuggestions(keywords: ['jay']));
      completers['ja']!.complete(const SearchSuggestions(keywords: ['ja']));
      await tester.pump();
      expect(debouncer.suggestions.value?.keywords, ['jay']);

      debouncer.update('');
      expect(debouncer.suggestions.value, isNull);
      debouncer.dispose();
    });

    testWidgets('cancel ignores a pending answer', (tester) async {
      final completer = Completer<SearchSuggestions>();
      final debouncer = SuggestionDebouncer(fetch: (_) => completer.future);
      debouncer.update('abc');
      await tester.pump(const Duration(milliseconds: 300));
      debouncer.cancel();
      completer.complete(const SearchSuggestions(keywords: ['abc']));
      await tester.pump();
      expect(debouncer.suggestions.value, isNull);
      debouncer.dispose();
    });
  });
}
