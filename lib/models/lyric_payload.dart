import 'dart:convert';

import 'json_utils.dart';

/// "作词: 唐恬" style credit taken from the JSON header lines NetEase embeds at
/// the top of `lrc` / `yrc`.
class LyricCredit {
  const LyricCredit({required this.role, required this.names});

  /// "作词", "作曲", "编曲"...
  final String role;
  final List<String> names;

  @override
  String toString() => '$role: ${names.join(' / ')}';
}

/// Raw lyric documents of a song, unparsed (parsing / timing belongs to the
/// lyric layer). Every text is `null` when missing or empty.
class LyricPayload {
  const LyricPayload({
    this.lrc,
    this.translation,
    this.romaji,
    this.yrc,
    this.yrcTranslation,
    this.yrcRomaji,
    this.pureMusic = false,
    this.uncollected = false,
    this.credits = const [],
    this.lyricUser,
    this.translationUser,
  });

  /// Line timed lyric (`lrc.lyric`).
  final String? lrc;

  /// `tlyric.lyric`.
  final String? translation;

  /// `romalrc.lyric`.
  final String? romaji;

  /// Word timed lyric (`yrc.lyric`), `[start,duration](t,d,0)word` lines.
  final String? yrc;

  /// `ytlrc.lyric`.
  final String? yrcTranslation;

  /// `yromalrc.lyric`.
  final String? yrcRomaji;

  /// Instrumental track, NetEase has no lyric for it on purpose.
  final bool pureMusic;

  /// Nobody uploaded lyrics yet (`uncollected` / `nolyric`).
  final bool uncollected;
  final List<LyricCredit> credits;

  /// Nickname of the lyric / translation contributors, when given.
  final String? lyricUser;
  final String? translationUser;

  bool get hasLrc => lrc != null;
  bool get hasYrc => yrc != null;
  bool get hasTranslation => translation != null || yrcTranslation != null;
  bool get hasRomaji => romaji != null || yrcRomaji != null;
  bool get isEmpty => lrc == null && yrc == null;

  static const String _pureMusicMarker = '纯音乐，请欣赏';

  /// Accepts both `/api/song/lyric/v1` and the legacy `/api/song/lyric`.
  factory LyricPayload.fromJson(Map<String, dynamic> body) {
    String? text(String key) => jsonText(jsonMap(body[key])?['lyric']);
    final lrc = text('lrc');
    final yrc = text('yrc');
    final pure =
        jsonBool(body['pureMusic']) ||
        (lrc != null &&
            lrc.contains(_pureMusicMarker) &&
            lrc.split('\n').where((l) => l.trim().isNotEmpty).length <= 2);
    return LyricPayload(
      lrc: lrc,
      translation: text('tlyric'),
      romaji: text('romalrc'),
      yrc: yrc,
      yrcTranslation: text('ytlrc'),
      yrcRomaji: text('yromalrc'),
      pureMusic: pure,
      uncollected: jsonBool(body['uncollected']) || jsonBool(body['nolyric']),
      credits: parseCredits(lrc).isNotEmpty
          ? parseCredits(lrc)
          : parseCredits(yrc),
      lyricUser: jsonText(jsonMap(body['lyricUser'])?['nickname']),
      translationUser: jsonText(jsonMap(body['transUser'])?['nickname']),
    );
  }

  /// Reads `{"t":0,"c":[{"tx":"作词: "},{"tx":"唐恬"}]}` header lines.
  static List<LyricCredit> parseCredits(String? document) {
    if (document == null) return const [];
    final credits = <LyricCredit>[];
    for (final line in const LineSplitter().convert(document)) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('{')) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(trimmed);
      } on FormatException {
        continue;
      }
      final parts = [
        for (final part in jsonMaps(jsonMap(decoded)?['c']))
          (jsonString(part['tx']) ?? '').trim(),
      ].where((part) => part.isNotEmpty).toList();
      if (parts.length < 2) continue;
      final role = parts.first.replaceAll(RegExp(r'[:：]\s*$'), '').trim();
      final names = parts
          .skip(1)
          .map((name) => name.replaceAll(RegExp(r'^[/、,，]+|[/、,，]+$'), ''))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList(growable: false);
      if (role.isEmpty || names.isEmpty) continue;
      credits.add(LyricCredit(role: role, names: names));
    }
    return credits;
  }
}
