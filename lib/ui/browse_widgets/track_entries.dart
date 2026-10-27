import '../../models/song.dart';

/// Pure list logic of track collections (filtering, disc grouping and the
/// scroll math of "定位当前播放"), kept free of widgets so it is unit tested.

/// Height of a track row.
const double kTrackRowExtent = 64;

/// Height of a "CD 2" disc header row.
const double kDiscHeaderExtent = 44;

/// One row of a track collection.
sealed class TrackEntry {
  const TrackEntry();

  double get extent;
}

class DiscHeaderEntry extends TrackEntry {
  const DiscHeaderEntry(this.disc);

  final int disc;

  @override
  double get extent => kDiscHeaderExtent;
}

class SongEntry extends TrackEntry {
  const SongEntry({
    required this.song,
    required this.sourceIndex,
    required this.label,
  });

  final Song song;

  /// Position in the unfiltered collection (what the queue is built from).
  final int sourceIndex;

  /// Track number shown in the row.
  final String label;

  @override
  double get extent => kTrackRowExtent;
}

/// Whether [song] matches a case-insensitive [query] on title, alias,
/// artists or album.
bool songMatches(Song song, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (song.name.toLowerCase().contains(q)) return true;
  if (song.album.name.toLowerCase().contains(q)) return true;
  for (final alias in song.alias) {
    if (alias.toLowerCase().contains(q)) return true;
  }
  for (final artist in song.artists) {
    if (artist.name.toLowerCase().contains(q)) return true;
  }
  return false;
}

/// Builds the visible rows for [songs].
///
/// With [byDisc] (albums) a header precedes every disc when the album has more
/// than one, and rows show the album track number (`no`) when known.
/// Filtering by [query] keeps the source index of every match and drops disc
/// headers (a filtered list is not grouped).
List<TrackEntry> buildTrackEntries(
  List<Song> songs, {
  String query = '',
  bool byDisc = false,
}) {
  final filtering = query.trim().isNotEmpty;
  final discs = byDisc
      ? songs.map((song) => song.cd ?? 1).toSet()
      : const <int>{};
  final grouped = byDisc && !filtering && discs.length > 1;
  final entries = <TrackEntry>[];
  int? lastDisc;
  for (var i = 0; i < songs.length; i++) {
    final song = songs[i];
    if (filtering && !songMatches(song, query)) continue;
    if (grouped) {
      final disc = song.cd ?? 1;
      if (disc != lastDisc) {
        entries.add(DiscHeaderEntry(disc));
        lastDisc = disc;
      }
    }
    final number = byDisc ? (song.no ?? i + 1) : i + 1;
    entries.add(
      SongEntry(
        song: song,
        sourceIndex: i,
        label: number.toString().padLeft(2, '0'),
      ),
    );
  }
  return entries;
}

/// Index into [entries] of the row playing [songId], or -1.
int entryIndexOfSong(List<TrackEntry> entries, int? songId) {
  if (songId == null) return -1;
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    if (entry is SongEntry && entry.song.id == songId) return i;
  }
  return -1;
}

/// Offset of row [index] from the start of the list.
double entryOffset(List<TrackEntry> entries, int index) {
  var offset = 0.0;
  for (var i = 0; i < index && i < entries.length; i++) {
    offset += entries[i].extent;
  }
  return offset;
}

/// Whether a row spanning [rowTop, rowTop + extent) (scroll coordinates) is
/// hidden, given the visible window [scrollOffset, scrollOffset + viewport)
/// minus [topInset] (floating header) and [bottomInset] (floating player).
bool isRowOffscreen({
  required double rowTop,
  required double extent,
  required double scrollOffset,
  required double viewport,
  double topInset = 0,
  double bottomInset = 0,
}) {
  final visibleTop = scrollOffset + topInset;
  final visibleBottom = scrollOffset + viewport - bottomInset;
  return rowTop + extent <= visibleTop || rowTop >= visibleBottom;
}

/// Scroll offset that centres a row in the visible window, clamped to the
/// scrollable range.
double centeredScrollTarget({
  required double rowTop,
  required double extent,
  required double viewport,
  required double maxScrollExtent,
  double topInset = 0,
  double bottomInset = 0,
}) {
  final visible = viewport - topInset - bottomInset;
  final target = rowTop - topInset - (visible - extent) / 2;
  return target.clamp(0.0, maxScrollExtent < 0 ? 0.0 : maxScrollExtent);
}
