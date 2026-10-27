import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../models/comment.dart';
import '../../models/comment_target.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../login/login_dialog.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';

/// Tabs of [CommentsView].
enum CommentTab {
  hot('热门', CommentSort.hot),
  latest('最新', CommentSort.latest);

  const CommentTab(this.label, this.sort);

  final String label;
  final CommentSort sort;
}

/// "刚刚" / "5分钟前" / "3小时前" / "昨天 12:00" / "3天前" / "06-12" /
/// "2021-06-12" relative to [now].
String relativeCommentTime(DateTime? time, {DateTime? now, String? fallback}) {
  if (time == null) return fallback ?? '';
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  String two(int v) => v.toString().padLeft(2, '0');
  if (diff.isNegative || diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  final days = today.difference(day).inDays;
  if (days == 0) return '${diff.inHours}小时前';
  if (days == 1) return '昨天 ${two(time.hour)}:${two(time.minute)}';
  if (days < 7) return '$days天前';
  if (time.year == current.year) return '${two(time.month)}-${two(time.day)}';
  return '${time.year}-${two(time.month)}-${two(time.day)}';
}

/// Paged comments of one sort, with optimistic like state.
class _Feed {
  final List<Comment> items = [];
  bool loading = false;
  bool hasMore = true;
  bool started = false;
  int page = 0;
  int? cursor;
  int total = 0;
  Object? error;
}

/// Hot + latest comments of a song / playlist / album with paging, like and
/// reply. Embeddable (now playing panel) and as a sheet.
class CommentsView extends StatefulWidget {
  const CommentsView({super.key, required this.target, this.embedded = false});

  final CommentTarget target;

  /// `true` inside the now playing screen (transparent background, no header).
  final bool embedded;

  @override
  State<CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends State<CommentsView> {
  static const int _pageSize = 20;

  CommentTab _tab = CommentTab.hot;
  final Map<CommentTab, _Feed> _feeds = {
    for (final tab in CommentTab.values) tab: _Feed(),
  };
  final Map<CommentTab, ScrollController> _scrolls = {
    for (final tab in CommentTab.values) tab: ScrollController(),
  };

  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  Comment? _replyTo;
  bool _sending = false;

  _Feed get _feed => _feeds[_tab]!;

  @override
  void initState() {
    super.initState();
    _load(_tab);
  }

  @override
  void didUpdateWidget(CommentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      for (final tab in CommentTab.values) {
        _feeds[tab] = _Feed();
      }
      _replyTo = null;
      _load(_tab);
    }
  }

  @override
  void dispose() {
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load(CommentTab tab, {bool refresh = false}) async {
    var feed = _feeds[tab]!;
    if (refresh) {
      feed = _feeds[tab] = _Feed();
    }
    if (feed.loading || (!feed.hasMore && feed.started)) return;
    final target = widget.target;
    setState(() {
      feed
        ..loading = true
        ..started = true
        ..error = null;
    });
    try {
      final page = await app.apiHost.api.comments(
        target,
        sort: tab.sort,
        pageSize: _pageSize,
        pageNo: feed.page + 1,
        cursor: feed.cursor,
      );
      if (!mounted || widget.target != target || _feeds[tab] != feed) return;
      final seen = {for (final c in feed.items) c.id};
      setState(() {
        feed.items.addAll(page.comments.where((c) => seen.add(c.id)));
        feed
          ..page += 1
          ..cursor = page.cursor
          ..total = page.total > 0 ? page.total : feed.total
          ..hasMore = page.hasMore && page.comments.isNotEmpty
          ..loading = false;
      });
    } catch (error) {
      if (!mounted || _feeds[tab] != feed) return;
      setState(() {
        feed
          ..loading = false
          ..error = error;
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < 600) {
      final feed = _feed;
      if (!feed.loading && feed.hasMore && feed.error == null) _load(_tab);
    }
    return false;
  }

  void _select(CommentTab tab) {
    if (tab == _tab) {
      final scroll = _scrolls[tab]!;
      if (scroll.hasClients) {
        scroll.animateTo(0, duration: AppMotion.page, curve: AppMotion.enter);
      }
      return;
    }
    setState(() => _tab = tab);
    if (!_feeds[tab]!.started) _load(tab);
  }

  // ------------------------------------------------------------- actions

  Future<bool> _ensureLogin() async {
    if (app.session.value.isLoggedIn) return true;
    return showLoginDialog(context);
  }

  void _replace(Comment updated) {
    for (final feed in _feeds.values) {
      final index = feed.items.indexWhere((c) => c.id == updated.id);
      if (index >= 0) feed.items[index] = updated;
    }
  }

  Future<void> _toggleLike(Comment comment) async {
    if (!await _ensureLogin() || !mounted) return;
    final like = !comment.liked;
    final optimistic = comment.copyWith(
      liked: like,
      likedCount: (comment.likedCount + (like ? 1 : -1)).clamp(0, 1 << 31),
    );
    setState(() => _replace(optimistic));
    try {
      await app.apiHost.api.likeComment(widget.target, comment.id, like: like);
    } catch (error) {
      if (!mounted) return;
      setState(() => _replace(comment));
      _toast('点赞失败：${describeError(error)}');
    }
  }

  void _startReply(Comment comment) {
    setState(() => _replyTo = comment);
    _inputFocus.requestFocus();
  }

  Future<void> _send() async {
    final text = normalizeCommentContent(_input.text);
    if (text.isEmpty || _sending) return;
    if (!await _ensureLogin() || !mounted) return;
    setState(() => _sending = true);
    final replyTo = _replyTo;
    try {
      final created = await app.apiHost.api.postComment(
        widget.target,
        text,
        replyToCommentId: replyTo?.id,
      );
      if (!mounted) return;
      final profile = app.session.value.profile;
      final comment =
          created ??
          Comment(
            id: -DateTime.now().millisecondsSinceEpoch,
            content: text,
            user: CommentUser(
              id: profile?.id ?? 0,
              nickname: profile?.nickname ?? '我',
              avatarUrl: profile?.avatarUrl,
              vipType: profile?.vipType ?? 0,
            ),
            time: DateTime.now(),
            beReplied: [
              if (replyTo != null)
                CommentReply(
                  id: replyTo.id,
                  user: replyTo.user,
                  content: replyTo.content,
                ),
            ],
          );
      setState(() {
        _input.clear();
        _replyTo = null;
        _sending = false;
        final latest = _feeds[CommentTab.latest]!;
        latest.items.insert(0, comment);
        latest.total += 1;
        _tab = CommentTab.latest;
      });
      _inputFocus.unfocus();
      _toast(replyTo == null ? '评论已发布' : '回复已发布');
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      _toast('发送失败：${describeError(error)}');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final title = widget.target.title;
    final total = _feeds[CommentTab.latest]!.total > 0
        ? _feeds[CommentTab.latest]!.total
        : _feeds.values.fold<int>(0, (a, f) => a > f.total ? a : f.total);
    final content = Column(
      children: [
        if (!widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title == null ? '评论' : '《$title》的评论',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                ),
                if (total > 0)
                  Text(
                    '${total.compact} 条',
                    style: context.text.bodySmall?.copyWith(
                      color: context.surfaces.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ChipBar<CommentTab>(
          values: CommentTab.values,
          selected: _tab,
          dense: true,
          padding: EdgeInsets.symmetric(horizontal: widget.embedded ? 0 : 20),
          labelOf: (tab) => tab.label,
          onSelected: _select,
        ),
        const SizedBox(height: 6),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.standard,
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            child: KeyedSubtree(key: ValueKey(_tab), child: _list(_tab)),
          ),
        ),
        _Composer(
          controller: _input,
          focusNode: _inputFocus,
          replyTo: _replyTo,
          sending: _sending,
          onCancelReply: () => setState(() => _replyTo = null),
          onSend: _send,
          embedded: widget.embedded,
        ),
      ],
    );
    if (widget.embedded) {
      return Material(type: MaterialType.transparency, child: content);
    }
    return content;
  }

  Widget _list(CommentTab tab) {
    final feed = _feeds[tab]!;
    if (feed.items.isEmpty) {
      if (feed.error != null) {
        return _Message(
          icon: Icons.cloud_off_rounded,
          text: describeError(feed.error!),
          action: '重试',
          onAction: () => _load(tab, refresh: true),
        );
      }
      if (feed.loading || !feed.started) return const _CommentSkeletons();
      return const _Message(
        icon: Icons.chat_bubble_outline_rounded,
        text: '还没有评论，来抢沙发吧',
      );
    }
    final footer = feed.loading
        ? const _CommentSkeletons(count: 2, shrink: true)
        : feed.error != null
        ? Center(
            child: TextButton(
              onPressed: () => _load(tab),
              child: const Text('加载失败，点此重试'),
            ),
          )
        : feed.hasMore
        ? const SizedBox(height: 40)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                '没有更多了',
                style: context.text.bodySmall?.copyWith(
                  color: context.surfaces.textTertiary,
                ),
              ),
            ),
          );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: () => _load(tab, refresh: true),
        child: ListView.builder(
          controller: _scrolls[tab],
          padding: EdgeInsets.fromLTRB(
            widget.embedded ? 0 : 12,
            4,
            widget.embedded ? 0 : 12,
            12,
          ),
          itemCount: feed.items.length + 1,
          itemBuilder: (context, index) {
            if (index == feed.items.length) return footer;
            final comment = feed.items[index];
            return _CommentRow(
              key: ValueKey(comment.id),
              comment: comment,
              onLike: () => _toggleLike(comment),
              onReply: () => _startReply(comment),
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- rows

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    super.key,
    required this.comment,
    required this.onLike,
    required this.onReply,
  });

  final Comment comment;
  final VoidCallback onLike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final user = comment.user;
    final meta = [
      relativeCommentTime(comment.time, fallback: comment.timeStr),
      if (comment.ipLocation != null) comment.ipLocation!,
    ].where((part) => part.isNotEmpty).join(' · ');
    return Pressable(
      pressedScale: 0.99,
      onTap: onReply,
      onLongPress: () => _showActions(context),
      onSecondaryTap: () => _showActions(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: CoverImage(
                url: user.avatarUrl,
                size: 100,
                width: 36,
                height: 36,
                radius: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.nickname.isEmpty ? '网易云用户' : user.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: s.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (user.vip) ...[
                        const SizedBox(width: 6),
                        TagBadge('VIP', color: s.peach),
                      ],
                    ],
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        meta,
                        style: TextStyle(fontSize: 11, color: s.textTertiary),
                      ),
                    ),
                  const SizedBox(height: 6),
                  SelectableText(
                    comment.content,
                    style: context.text.bodyMedium?.copyWith(height: 1.5),
                  ),
                  for (final reply in comment.beReplied)
                    _QuotedReply(reply: reply),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _LikeButton(
              liked: comment.liked,
              count: comment.likedCount,
              onTap: onLike,
            ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('回复'),
              onTap: () {
                Navigator.pop(sheet);
                onReply();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(sheet);
                unawaited(_copy(context));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: comment.content));
    messenger?.showSnackBar(const SnackBar(content: Text('已复制评论')));
  }
}

class _QuotedReply extends StatelessWidget {
  const _QuotedReply({required this.reply});

  final CommentReply reply;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: s.chip.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
        border: Border(left: BorderSide(color: s.hairline, width: 3)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '@${reply.user.nickname}：',
              style: TextStyle(
                color: s.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: reply.content),
          ],
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall?.copyWith(
          color: s.textSecondary,
          height: 1.45,
        ),
      ),
    );
  }
}

/// Heart with a pop on like and a rolling count.
class _LikeButton extends StatefulWidget {
  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.liked && !oldWidget.liked) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  static double _popScale(double t) {
    // 1 → 1.35 → 0.92 → 1
    if (t < 0.35) return 1 + 0.35 * Curves.easeOut.transform(t / 0.35);
    if (t < 0.7) {
      return 1.35 - 0.43 * Curves.easeInOut.transform((t - 0.35) / 0.35);
    }
    return 0.92 + 0.08 * Curves.easeOut.transform((t - 0.7) / 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final color = widget.liked ? const Color(0xFFFF5C8A) : s.textTertiary;
    return Semantics(
      button: true,
      toggled: widget.liked,
      label: widget.liked ? '取消点赞' : '点赞',
      child: Pressable(
        onTap: widget.onTap,
        pressedScale: 0.9,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 4, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RollingCount(
                value: widget.count,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: _pop,
                builder: (context, child) => Transform.scale(
                  scale: _pop.isAnimating ? _popScale(_pop.value) : 1,
                  child: child,
                ),
                child: AnimatedSwitcher(
                  duration: AppMotion.quick,
                  child: Icon(
                    widget.liked
                        ? Icons.thumb_up_alt_rounded
                        : Icons.thumb_up_alt_outlined,
                    key: ValueKey(widget.liked),
                    size: 17,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Count that rolls up / down when it changes.
class _RollingCount extends StatelessWidget {
  const _RollingCount({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final text = value <= 0 ? '' : value.compact;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: AppMotion.standard,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerRight,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(text);
          final offset = Tween(
            begin: Offset(0, incoming ? 0.8 : -0.8),
            end: Offset.zero,
          ).animate(animation);
          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Text(text, key: ValueKey(text), style: style),
      ),
    );
  }
}

// --------------------------------------------------------------- composer

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.sending,
    required this.onCancelReply,
    required this.onSend,
    required this.embedded,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Comment? replyTo;
  final bool sending;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final replyTo = this.replyTo;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        embedded ? 0 : 16,
        6,
        embedded ? 0 : 16,
        12 + MediaQuery.viewInsetsOf(context).bottom * (embedded ? 0 : 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: AppMotion.standard,
            curve: AppMotion.enter,
            alignment: Alignment.topLeft,
            child: replyTo == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: Row(
                      children: [
                        Icon(Icons.reply_rounded, size: 14, color: s.lime),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '回复 @${replyTo.user.nickname}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: s.lime),
                          ),
                        ),
                        Tooltip(
                          message: '取消回复',
                          child: Pressable(
                            onTap: onCancelReply,
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: s.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Row(
            children: [
              Expanded(
                child: ListenableBuilder(
                  listenable: app.session,
                  builder: (context, _) {
                    final loggedIn = app.session.value.isLoggedIn;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: !loggedIn,
                      onTap: loggedIn ? null : () => showLoginDialog(context),
                      minLines: 1,
                      maxLines: 4,
                      maxLength: commentMaxLength,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        isDense: true,
                        counterText: '',
                        hintText: loggedIn ? '说点什么…' : '登录后发表评论',
                        filled: true,
                        fillColor: s.chip.withValues(alpha: 0.7),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppMetrics.radiusLg,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (context, value, _) {
                  final ready = value.text.trim().isNotEmpty && !sending;
                  return AnimatedScale(
                    scale: ready ? 1 : 0.9,
                    duration: AppMotion.quick,
                    curve: AppMotion.pop,
                    child: RoundIconButton(
                      icon: Icons.send_rounded,
                      tooltip: '发送',
                      size: 44,
                      color: ready ? s.lime : s.chip,
                      iconColor: ready ? s.onLime : s.textTertiary,
                      onPressed: ready ? onSend : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- states

class _CommentSkeletons extends StatelessWidget {
  const _CommentSkeletons({this.count = 6, this.shrink = false});

  final int count;
  final bool shrink;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Skeleton(width: 36, height: 36, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Skeleton(width: 96, height: 11),
                    const SizedBox(height: 8),
                    const Skeleton(height: 13),
                    const SizedBox(height: 6),
                    Skeleton(width: i.isEven ? 180 : 120, height: 13),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
    if (shrink) return Column(children: rows);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: rows,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: s.textTertiary),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: s.textSecondary),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens [CommentsView] as a tall bottom sheet.
Future<void> showComments(BuildContext context, CommentTarget target) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.88,
      child: CommentsView(target: target),
    ),
  );
}
