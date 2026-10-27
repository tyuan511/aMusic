import 'dart:convert';
import 'dart:math' as math;

import 'lyric_payload.dart';

/// One word (or syllable) of a word-timed (YRC) line.
class LyricWord {
  const LyricWord({
    required this.start,
    required this.duration,
    required this.text,
  });

  /// Absolute start in the track.
  final Duration start;
  final Duration duration;
  final String text;

  Duration get end => start + duration;

  /// 0 before the word, 1 after it, linear in between.
  double progressAt(Duration position) {
    if (position <= start) return 0;
    if (duration <= Duration.zero || position >= end) return 1;
    return (position - start).inMicroseconds / duration.inMicroseconds;
  }
}

/// One timestamped lyric line, optionally with translation, romanisation and
/// word timing.
class LyricLine {
  const LyricLine({
    required this.time,
    required this.text,
    this.translation,
    this.romaji,
    this.words = const [],
    this.duration,
  });

  final Duration time;
  final String text;
  final String? translation;
  final String? romaji;

  /// Word timing from YRC; empty for line-timed lyrics.
  final List<LyricWord> words;

  /// Explicit line length (YRC), `null` when only the next line's start is
  /// known.
  final Duration? duration;

  bool get isEmpty => text.trim().isEmpty;
  bool get hasWords => words.isNotEmpty;

  LyricLine copyWith({
    String? translation,
    String? romaji,
    bool clearTranslation = false,
    bool clearRomaji = false,
  }) => LyricLine(
    time: time,
    text: text,
    translation: clearTranslation ? null : (translation ?? this.translation),
    romaji: clearRomaji ? null : (romaji ?? this.romaji),
    words: words,
    duration: duration,
  );
}

/// A parsed lyric document.
class Lyric {
  const Lyric({
    required this.lines,
    this.raw = '',
    this.credits = const [],
    this.pureMusic = false,
    this.imported = false,
  });

  static const Lyric empty = Lyric(lines: []);

  final List<LyricLine> lines;
  final String raw;

  /// "作词 / 作曲" credits pulled out of the header lines.
  final List<LyricCredit> credits;

  /// Instrumental track: there is nothing to sing.
  final bool pureMusic;

  /// Loaded from a user imported `.lrc` file instead of the cloud.
  final bool imported;

  bool get isEmpty => lines.isEmpty;
  bool get hasTranslation =>
      lines.any((line) => (line.translation ?? '').isNotEmpty);
  bool get hasRomaji => lines.any((line) => (line.romaji ?? '').isNotEmpty);
  bool get hasWordTiming => lines.any((line) => line.hasWords);

  Lyric copyWith({bool? imported, bool? pureMusic}) => Lyric(
    lines: lines,
    raw: raw,
    credits: credits,
    pureMusic: pureMusic ?? this.pureMusic,
    imported: imported ?? this.imported,
  );

  /// Index of the line that should be highlighted at [position], or `-1`.
  int lineIndexAt(Duration position) {
    if (lines.isEmpty) return -1;
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }

  /// When line [index] stops being current: its own duration (YRC) or the
  /// next line's start.
  Duration endOf(int index) {
    final line = lines[index];
    final next = index + 1 < lines.length ? lines[index + 1].time : null;
    final own = line.duration == null ? null : line.time + line.duration!;
    if (own != null && next != null) return own < next ? own : next;
    return own ?? next ?? line.time + const Duration(seconds: 5);
  }

  /// Builds a merged lyric from the line timed [lrc], optional word timed
  /// [yrc] and the translation / romaji sidecars. The word timed document
  /// wins when it parses.
  factory Lyric.parse({
    String? lrc,
    String? tlyric,
    String? romalrc,
    String? yrc,
    String? ytlrc,
    String? yromalrc,
    bool pureMusic = false,
  }) {
    final credits = <LyricCredit>[];
    var main = yrc == null ? const <LyricLine>[] : parseYrc(yrc, credits);
    final usedYrc = main.isNotEmpty;
    if (!usedYrc) {
      credits.clear();
      main = parseLrc(lrc, credits: credits);
    }
    if (main.isEmpty) {
      return Lyric(
        lines: const [],
        raw: lrc ?? yrc ?? '',
        credits: credits,
        pureMusic: pureMusic,
      );
    }
    final translations = parseLrc(
      usedYrc ? (ytlrc ?? tlyric) : (tlyric ?? ytlrc),
    );
    final romaji = parseLrc(usedYrc ? (yromalrc ?? romalrc) : romalrc);
    final translated = matchSidecar(main, translations);
    final romanised = matchSidecar(main, romaji);
    return Lyric(
      lines: [
        for (var i = 0; i < main.length; i++)
          LyricLine(
            time: main[i].time,
            text: main[i].text,
            words: main[i].words,
            duration: main[i].duration,
            translation: translated[i],
            romaji: romanised[i],
          ),
      ],
      raw: (usedYrc ? yrc : lrc) ?? '',
      credits: credits,
      pureMusic: pureMusic,
    );
  }

  /// From the raw documents of `/api/song/lyric/v1`.
  factory Lyric.fromPayload(LyricPayload payload) {
    final lyric = Lyric.parse(
      lrc: payload.lrc,
      tlyric: payload.translation,
      romalrc: payload.romaji,
      yrc: payload.yrc,
      ytlrc: payload.yrcTranslation,
      yromalrc: payload.yrcRomaji,
      pureMusic: payload.pureMusic,
    );
    if (lyric.credits.isNotEmpty || payload.credits.isEmpty) return lyric;
    return Lyric(
      lines: lyric.lines,
      raw: lyric.raw,
      credits: payload.credits,
      pureMusic: lyric.pureMusic,
    );
  }

  // ------------------------------------------------------------- matching

  /// Largest distance a sidecar line may be from its original line.
  static const Duration matchWindow = Duration(milliseconds: 600);

  /// Assigns every [sidecar] line (translation / romaji) to the nearest
  /// [main] line. A line accepts a candidate only within
  /// `min(600 ms, half the gap to its nearer neighbour)`, so a translation
  /// never jumps onto the line before or after. When several candidates
  /// compete for one line, the closest wins. Returns one entry per main line.
  static List<String?> matchSidecar(
    List<LyricLine> main,
    List<LyricLine> sidecar,
  ) {
    final result = List<String?>.filled(main.length, null);
    if (main.isEmpty || sidecar.isEmpty) return result;
    final bestDistance = List<int>.filled(main.length, 1 << 62);
    for (final candidate in sidecar) {
      final text = _cleanSidecar(candidate.text);
      if (text == null) continue;
      final t = candidate.time.inMilliseconds;
      final index = _nearestIndex(main, candidate.time);
      final distance = (main[index].time.inMilliseconds - t).abs();
      if (distance > toleranceFor(main, index).inMilliseconds) continue;
      if (distance < bestDistance[index]) {
        bestDistance[index] = distance;
        result[index] = text;
      }
    }
    return result;
  }

  /// `min(600 ms, half the gap to the closer neighbour of line [index])`.
  static Duration toleranceFor(List<LyricLine> main, int index) {
    var window = matchWindow.inMilliseconds;
    final t = main[index].time.inMilliseconds;
    if (index > 0) {
      window = math.min(window, (t - main[index - 1].time.inMilliseconds) ~/ 2);
    }
    if (index + 1 < main.length) {
      window = math.min(window, (main[index + 1].time.inMilliseconds - t) ~/ 2);
    }
    return Duration(milliseconds: math.max(0, window));
  }

  static int _nearestIndex(List<LyricLine> lines, Duration time) {
    var low = 0;
    var high = lines.length - 1;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    // `low` is the first line at or after [time]; compare with the previous.
    if (low > 0) {
      final before = (time - lines[low - 1].time).inMicroseconds.abs();
      final after = (lines[low].time - time).inMicroseconds.abs();
      if (before <= after) return low - 1;
    }
    return low;
  }

  /// NetEase pads untranslated lines with `//` or a lone slash.
  static String? _cleanSidecar(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == '//' || trimmed == '/') return null;
    return trimmed;
  }

  // ------------------------------------------------------------------ LRC

  static final RegExp _tagRegExp = RegExp(r'\[([^\]]*)\]');
  static final RegExp _timeRegExp = RegExp(
    r'^\s*(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\s*$',
  );
  static final RegExp _offsetRegExp = RegExp(
    r'^\s*offset\s*:\s*([+-]?\d+)\s*$',
    caseSensitive: false,
  );

  /// Credit roles NetEase writes as plain timed lines ("作词 : 方文山").
  static final RegExp _creditLine = RegExp(
    r'^\s*(作词|作曲|编曲|制作人|制作|监制|混音|母带|录音|和声|吉他|贝斯|鼓|键盘|弦乐|'
    r'人声编辑|配唱制作人|出品|发行|OP|SP|Lyrics?|Composer|Arranger|Producer|'
    r'Mix(?:ing)?|Master(?:ing)?)\s*[:：]\s*(.+)$',
    caseSensitive: false,
  );

  /// Parses an LRC document: several timestamps per line, 1 - 3 digit
  /// fractions, `[offset:]`, metadata tags skipped, JSON credit lines
  /// (`{"t":0,"c":[...]}`) and leading "作词: ..." lines moved to [credits].
  static List<LyricLine> parseLrc(
    String? content, {
    List<LyricCredit>? credits,
  }) {
    if (content == null || content.trim().isEmpty) return const [];
    var offset = 0;
    final lines = <LyricLine>[];
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('{')) {
        credits?.addAll(LyricPayload.parseCredits(line));
        continue;
      }
      var rest = line;
      final times = <Duration>[];
      while (rest.startsWith('[')) {
        final match = _tagRegExp.matchAsPrefix(rest);
        if (match == null) break;
        final tag = match.group(1) ?? '';
        final time = _parseTime(tag);
        if (time != null) {
          times.add(time);
        } else {
          final offsetMatch = _offsetRegExp.firstMatch(tag);
          if (offsetMatch != null) offset = int.parse(offsetMatch.group(1)!);
        }
        rest = rest.substring(match.end);
      }
      if (times.isEmpty) continue;
      final text = rest.trim();
      for (final time in times) {
        lines.add(LyricLine(time: time, text: text));
      }
    }
    if (offset != 0) {
      // A positive offset shows the lyric earlier.
      for (var i = 0; i < lines.length; i++) {
        final shifted = lines[i].time - Duration(milliseconds: offset);
        lines[i] = LyricLine(
          time: shifted < Duration.zero ? Duration.zero : shifted,
          text: lines[i].text,
        );
      }
    }
    _stableSortByTime(lines);
    return _trim(lines, credits);
  }

  static Duration? _parseTime(String tag) {
    final match = _timeRegExp.firstMatch(tag);
    if (match == null) return null;
    final minutes = int.parse(match.group(1)!);
    final seconds = int.parse(match.group(2)!);
    if (seconds > 59) return null;
    final fraction = match.group(3) ?? '';
    final millis = switch (fraction.length) {
      0 => 0,
      1 => int.parse(fraction) * 100,
      2 => int.parse(fraction) * 10,
      _ => int.parse(fraction),
    };
    return Duration(minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  // ------------------------------------------------------------------ YRC

  static final RegExp _yrcLineHead = RegExp(r'^\[(\d+),(\d+)\]');
  static final RegExp _yrcWordHead = RegExp(r'\((\d+),(\d+),\d+\)');

  /// Parses NetEase word timed lyrics:
  /// `[lineStart,lineDuration](wordStart,wordDuration,0)word...`.
  static List<LyricLine> parseYrc(
    String content, [
    List<LyricCredit>? credits,
  ]) {
    final lines = <LyricLine>[];
    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('{')) {
        credits?.addAll(LyricPayload.parseCredits(line));
        continue;
      }
      final head = _yrcLineHead.firstMatch(line);
      if (head == null) continue;
      final lineStart = int.parse(head.group(1)!);
      final lineDuration = int.parse(head.group(2)!);
      final body = line.substring(head.end);
      final heads = _yrcWordHead.allMatches(body).toList();
      final words = <LyricWord>[];
      for (var i = 0; i < heads.length; i++) {
        final textEnd = i + 1 < heads.length ? heads[i + 1].start : body.length;
        final text = body.substring(heads[i].end, textEnd);
        if (text.isEmpty) continue;
        var start = int.parse(heads[i].group(1)!);
        // A few documents use offsets relative to the line start.
        if (start < lineStart && start <= lineDuration) start += lineStart;
        words.add(
          LyricWord(
            start: Duration(milliseconds: start),
            duration: Duration(milliseconds: int.parse(heads[i].group(2)!)),
            text: text,
          ),
        );
      }
      final text = heads.isEmpty
          ? body.trim()
          : words.map((word) => word.text).join().trim();
      lines.add(
        LyricLine(
          time: Duration(milliseconds: lineStart),
          duration: Duration(milliseconds: lineDuration),
          text: text,
          words: words,
        ),
      );
    }
    _stableSortByTime(lines);
    return _trim(lines, credits);
  }

  // --------------------------------------------------------------- helpers

  static void _stableSortByTime(List<LyricLine> lines) {
    final indexed = [for (var i = 0; i < lines.length; i++) (i, lines[i])];
    indexed.sort((a, b) {
      final byTime = a.$2.time.compareTo(b.$2.time);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
    for (var i = 0; i < indexed.length; i++) {
      lines[i] = indexed[i].$2;
    }
  }

  /// Drops leading empty lines and moves the leading "作词: x" block into
  /// [credits].
  static List<LyricLine> _trim(
    List<LyricLine> lines,
    List<LyricCredit>? credits,
  ) {
    var start = 0;
    while (start < lines.length) {
      final line = lines[start];
      if (line.isEmpty) {
        start++;
        continue;
      }
      final match = _creditLine.firstMatch(line.text);
      if (match == null) break;
      final names = match
          .group(2)!
          .split(RegExp(r'\s*[/、,，&]\s*'))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      if (names.isNotEmpty) {
        credits?.add(LyricCredit(role: match.group(1)!.trim(), names: names));
      }
      start++;
    }
    // Only a whole block of credits is moved; a song whose first sung line
    // happens to look like one keeps it when nothing follows.
    if (start >= lines.length) {
      start = 0;
      while (start < lines.length && lines[start].isEmpty) {
        start++;
      }
    }
    return start == 0 ? lines : lines.sublist(start);
  }
}
