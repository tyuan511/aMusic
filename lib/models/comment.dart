import 'json_utils.dart';

/// Sort order of `/api/v2/resource/comments` (`sortType`).
enum CommentSort {
  recommend(1, '推荐'),
  hot(2, '最热'),
  latest(3, '最新');

  const CommentSort(this.sortType, this.label);

  final int sortType;
  final String label;
}

/// Longest comment NetEase accepts, in characters (code points).
const int commentMaxLength = 140;

/// Trims [content] and cuts it to at most [max] code points (runes, not
/// UTF-16 units), backing off to the previous grapheme boundary so an emoji,
/// a ZWJ sequence, a skin tone, a keycap or a flag is never split.
String normalizeCommentContent(String content, {int max = commentMaxLength}) {
  final trimmed = content.trim();
  final runes = trimmed.runes.toList(growable: false);
  if (runes.length <= max) return trimmed;
  var end = max;
  while (end > 0 && _continuesCluster(runes, end)) {
    end--;
  }
  return String.fromCharCodes(runes.take(end)).trimRight();
}

/// Whether `runes[index]` belongs to the same user visible character as
/// `runes[index - 1]`.
bool _continuesCluster(List<int> runes, int index) {
  if (index <= 0 || index >= runes.length) return false;
  final current = runes[index];
  final previous = runes[index - 1];
  if (previous == 0x200D || _isExtender(current)) return true;
  if (_isRegionalIndicator(previous) && _isRegionalIndicator(current)) {
    // Flags are pairs: inside a pair when an odd number of indicators
    // precede [index].
    var count = 0;
    for (var i = index - 1; i >= 0 && _isRegionalIndicator(runes[i]); i--) {
      count++;
    }
    return count.isOdd;
  }
  return false;
}

bool _isExtender(int rune) =>
    rune == 0x200D || // zero width joiner
    (rune >= 0xFE00 && rune <= 0xFE0F) || // variation selectors
    (rune >= 0x1F3FB && rune <= 0x1F3FF) || // skin tones
    (rune >= 0x0300 && rune <= 0x036F) || // combining diacritics
    (rune >= 0xE0020 && rune <= 0xE007F) || // tag sequences
    rune == 0x20E3; // keycap

bool _isRegionalIndicator(int rune) => rune >= 0x1F1E6 && rune <= 0x1F1FF;

/// Author of a comment.
class CommentUser {
  const CommentUser({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.vipType = 0,
  });

  final int id;
  final String nickname;
  final String? avatarUrl;
  final int vipType;

  bool get vip => vipType != 0;

  factory CommentUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CommentUser(id: 0, nickname: '');
    return CommentUser(
      id: jsonInt(json['userId'] ?? json['id']),
      nickname: jsonString(json['nickname']) ?? '',
      avatarUrl: jsonText(json['avatarUrl']),
      vipType: jsonInt(json['vipType']),
    );
  }
}

/// The comment a reply answers (`beReplied[]`).
class CommentReply {
  const CommentReply({required this.user, required this.content, this.id = 0});

  final int id;
  final CommentUser user;

  /// "该评论已删除" when the original is gone.
  final String content;
}

class Comment {
  const Comment({
    required this.id,
    required this.content,
    required this.user,
    this.time,
    this.timeStr,
    this.likedCount = 0,
    this.liked = false,
    this.ipLocation,
    this.beReplied = const [],
    this.replyCount = 0,
    this.parentCommentId = 0,
  });

  final int id;
  final String content;
  final CommentUser user;
  final DateTime? time;

  /// Server formatted date ("2014-10-17", "昨天 12:00").
  final String? timeStr;
  final int likedCount;
  final bool liked;

  /// "广东", `null` when hidden.
  final String? ipLocation;
  final List<CommentReply> beReplied;
  final int replyCount;
  final int parentCommentId;

  Comment copyWith({bool? liked, int? likedCount}) => Comment(
    id: id,
    content: content,
    user: user,
    time: time,
    timeStr: timeStr,
    likedCount: likedCount ?? this.likedCount,
    liked: liked ?? this.liked,
    ipLocation: ipLocation,
    beReplied: beReplied,
    replyCount: replyCount,
    parentCommentId: parentCommentId,
  );

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: jsonInt(json['commentId'] ?? json['id']),
    content: jsonString(json['content']) ?? '',
    user: CommentUser.fromJson(jsonMap(json['user'])),
    time: jsonTime(json['time']),
    timeStr: jsonText(json['timeStr']),
    likedCount: jsonInt(json['likedCount']),
    liked: jsonBool(json['liked']),
    ipLocation: jsonText(jsonMap(json['ipLocation'])?['location']),
    beReplied: [
      for (final reply in jsonMaps(json['beReplied']))
        CommentReply(
          id: jsonInt(reply['beRepliedCommentId'] ?? reply['commentId']),
          user: CommentUser.fromJson(jsonMap(reply['user'])),
          content: jsonString(reply['content']) ?? '该评论已删除',
        ),
    ],
    replyCount: jsonInt(
      json['replyCount'] ?? jsonMap(json['showFloorComment'])?['replyCount'],
    ),
    parentCommentId: jsonInt(json['parentCommentId']),
  );

  static List<Comment> listFrom(Object? raw) => [
    for (final map in jsonMaps(raw))
      if (jsonInt(map['commentId'] ?? map['id']) > 0) Comment.fromJson(map),
  ];
}

/// One page of a comment thread.
class CommentPage {
  const CommentPage({
    this.total = 0,
    this.hasMore = false,
    this.cursor,
    this.comments = const [],
    this.hotComments = const [],
  });

  final int total;
  final bool hasMore;

  /// Pass back as `cursor` with the next `pageNo` for [CommentSort.latest]
  /// (time cursor); `null` for the offset based sorts.
  final int? cursor;
  final List<Comment> comments;

  /// Only on the first page and only when [comments] is not already sorted
  /// by heat.
  final List<Comment> hotComments;

  /// `data` of `/api/v2/resource/comments`.
  factory CommentPage.fromV2(
    Map<String, dynamic> data, {
    List<Comment> hotComments = const [],
  }) => CommentPage(
    total: jsonInt(data['totalCount'] ?? data['total']),
    hasMore: jsonBool(data['hasMore']),
    cursor: jsonIntOrNull(data['cursor']),
    comments: Comment.listFrom(data['comments']),
    hotComments: hotComments.isNotEmpty
        ? hotComments
        : Comment.listFrom(data['hotComments']),
  );

  /// Body of `/api/v1/resource/comments/{threadId}`.
  factory CommentPage.fromV1(Map<String, dynamic> body) {
    final comments = Comment.listFrom(body['comments']);
    final last = comments.isEmpty ? null : comments.last.time;
    return CommentPage(
      total: jsonInt(body['total']),
      hasMore: jsonBool(body['more']),
      cursor: last?.millisecondsSinceEpoch,
      comments: comments,
      hotComments: Comment.listFrom(body['hotComments']),
    );
  }
}
