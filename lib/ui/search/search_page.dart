import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/search.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/layout.dart';
import '../widgets/kit.dart';
import 'search_discovery.dart';
import 'search_field.dart';
import 'search_results.dart';
import 'search_session.dart';

/// What the body of the search page shows.
enum _Mode { discovery, suggestions, results }

/// 搜索: pill field with live (debounced) suggestions, history and hot list
/// while idle, and 单曲 / 专辑 / 歌手 / 歌单 result tabs whose results stay
/// cached while switching.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialKeyword});

  /// Searched right away when the page opens (from an artist tag, a hot word
  /// elsewhere ...). A new value searches again.
  final String? initialKeyword;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final SearchSession _session = SearchSession();
  late final SuggestionDebouncer _suggest = SuggestionDebouncer(
    fetch: app.library.searchSuggestions,
  );

  SearchTab _tab = SearchTab.songs;
  List<String> _history = const [];
  List<String>? _hotWords;
  String? _defaultKeyword;
  String? _defaultHint;

  @override
  void initState() {
    super.initState();
    _history = app.settings.searchHistory;
    _focus.addListener(_onFocus);
    unawaited(_loadDiscovery());
    final initial = widget.initialKeyword?.trim();
    if (initial != null && initial.isNotEmpty) _submit(initial);
  }

  @override
  void didUpdateWidget(SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final keyword = widget.initialKeyword?.trim();
    if (keyword != null &&
        keyword.isNotEmpty &&
        keyword != oldWidget.initialKeyword?.trim()) {
      _submit(keyword);
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    _controller.dispose();
    _session.dispose();
    _suggest.dispose();
    super.dispose();
  }

  Future<void> _loadDiscovery() async {
    try {
      final words = await app.library.hotSearchWords();
      if (mounted) setState(() => _hotWords = words);
    } on Object {
      if (mounted) setState(() => _hotWords = const []);
    }
    try {
      final keyword = await app.library.defaultKeyword();
      if (mounted && keyword.keyword.isNotEmpty) {
        setState(() {
          _defaultKeyword = keyword.keyword;
          _defaultHint = keyword.display;
        });
      }
    } on Object {
      // The placeholder keyword is decorative.
    }
  }

  void _onFocus() => setState(() {});

  void _onChanged(String text) {
    if (text.trim() == _session.keyword) {
      _suggest.cancel();
    } else {
      _suggest.update(text);
    }
    setState(() {});
  }

  void _submit(String raw) {
    var keyword = raw.trim();
    if (keyword.isEmpty) keyword = _defaultKeyword ?? '';
    if (keyword.isEmpty) return;
    if (_controller.text != keyword) {
      _controller.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
    _suggest.cancel();
    _focus.unfocus();
    app.settings.pushSearchHistory(keyword);
    setState(() {
      _history = app.settings.searchHistory;
      _session.setKeyword(keyword);
    });
  }

  void _clear() {
    _controller.clear();
    _suggest.cancel();
    setState(() => _session.setKeyword(''));
    _focus.requestFocus();
  }

  void _removeHistory(String keyword) {
    app.settings.removeSearchHistory(keyword);
    setState(() => _history = app.settings.searchHistory);
  }

  void _clearHistory() {
    app.settings.clearSearchHistory();
    setState(() => _history = const []);
  }

  _Mode _mode(SearchSuggestions? suggestions) {
    final text = _controller.text.trim();
    final typingNew = text.isNotEmpty && text != _session.keyword;
    if (typingNew && suggestions != null) return _Mode.suggestions;
    if (_session.keyword.isNotEmpty && !typingNew) return _Mode.results;
    if (typingNew) return _Mode.suggestions;
    return _Mode.discovery;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Column(
          children: [
            ContentBox(
              padding: EdgeInsets.fromLTRB(
                AppMetrics.gutter,
                top + 20,
                AppMetrics.gutter,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '搜索',
                    style: context.text.headlineMedium?.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SearchField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    onSubmitted: _submit,
                    onClear: _clear,
                    hint: _defaultHint ?? '搜索歌曲、歌手、专辑、歌单',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<SearchSuggestions?>(
                valueListenable: _suggest.suggestions,
                builder: (context, suggestions, _) {
                  final mode = _mode(suggestions);
                  return AnimatedSwitcher(
                    duration: AppMotion.standard,
                    switchInCurve: AppMotion.enter,
                    switchOutCurve: AppMotion.exit,
                    transitionBuilder: fadeThroughTransition,
                    layoutBuilder: topStackLayout,
                    child: KeyedSubtree(
                      key: ValueKey(mode),
                      child: _body(mode, suggestions),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _body(_Mode mode, SearchSuggestions? suggestions) {
    switch (mode) {
      case _Mode.discovery:
        return ContentBox(
          child: SearchDiscovery(
            history: _history,
            hotWords: _hotWords,
            onSearch: _submit,
            onRemoveHistory: _removeHistory,
            onClearHistory: _clearHistory,
          ),
        );
      case _Mode.suggestions:
        return ContentBox(
          child: SuggestionsPanel(
            query: _controller.text.trim(),
            suggestions: suggestions ?? SearchSuggestions.empty,
            onSearch: _submit,
          ),
        );
      case _Mode.results:
        return Column(
          children: [
            ContentBox(
              padding: const EdgeInsets.only(bottom: 8),
              child: ChipBar<SearchTab>(
                values: SearchTab.values,
                selected: _tab,
                labelOf: (tab) => tab.label,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.standard,
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: fadeThroughTransition,
                layoutBuilder: topStackLayout,
                child: SearchResultsList(
                  key: ValueKey('${_session.keyword}-${_tab.name}'),
                  session: _session,
                  tab: _tab,
                ),
              ),
            ),
          ],
        );
    }
  }
}
