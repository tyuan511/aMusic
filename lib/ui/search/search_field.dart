import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/kit.dart';

/// Big pill search field; a lime ring and glow animate in while focused.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.hint = '搜索歌曲、歌手、专辑、歌单',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final String hint;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (_focused != widget.focusNode.hasFocus) {
      setState(() => _focused = widget.focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    const none = InputBorder.none;
    return AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.enter,
      height: 58,
      padding: const EdgeInsets.only(left: 20, right: 8),
      decoration: BoxDecoration(
        color: _focused ? s.cardHover : s.chip,
        borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
        border: Border.all(
          color: _focused ? s.lime.withValues(alpha: 0.85) : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused ? s.glow : s.glow.withValues(alpha: 0),
            blurRadius: _focused ? 26 : 0,
            spreadRadius: _focused ? 1 : 0,
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedScale(
            scale: _focused ? 1.1 : 1,
            duration: AppMotion.standard,
            curve: AppMotion.pop,
            child: Icon(
              Icons.search_rounded,
              size: 24,
              color: _focused ? s.lime : s.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const ValueKey('search-field'),
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              style: context.text.bodyLarge?.copyWith(fontSize: 16.5),
              cursorColor: s.lime,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintMaxLines: 1,
                filled: false,
                isCollapsed: true,
                border: none,
                enabledBorder: none,
                focusedBorder: none,
                disabledBorder: none,
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: widget.controller,
            builder: (context, value, _) => AnimatedSwitcher(
              duration: AppMotion.quick,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: value.text.isEmpty
                  ? const SizedBox(key: ValueKey('empty'), width: 40)
                  : RoundIconButton(
                      key: const ValueKey('clear'),
                      icon: Icons.close_rounded,
                      tooltip: '清除',
                      size: 40,
                      onPressed: widget.onClear,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
