/// What a comment thread belongs to.
///
/// NetEase thread ids are `<prefix><id>`: `R_SO_4_` songs, `A_PL_0_`
/// playlists, `R_AL_3_` albums.
enum CommentResource {
  song('R_SO_4_', 0),
  playlist('A_PL_0_', 2),
  album('R_AL_3_', 3);

  const CommentResource(this.threadPrefix, this.typeCode);

  final String threadPrefix;

  /// The `type` code used by the comment write endpoints.
  final int typeCode;
}

class CommentTarget {
  const CommentTarget(this.resource, this.id, {this.title});

  final CommentResource resource;
  final int id;

  /// Shown in the sheet header ("《晴天》的评论").
  final String? title;

  String get threadId => '${resource.threadPrefix}$id';

  @override
  bool operator ==(Object other) =>
      other is CommentTarget && other.resource == resource && other.id == id;

  @override
  int get hashCode => Object.hash(resource, id);
}
