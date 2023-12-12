import 'package:json_annotation/json_annotation.dart';

part 'lyric.g.dart';

@JsonSerializable()
class LyricRow {
  final Duration time;
  final String text;

  LyricRow({
    required this.time,
    required this.text,
  });

  static Duration? _parseTime(String timeString) {
    final regExp = RegExp(r'^(\d+):(\d+)\.(\d+)$');
    final matched = regExp.firstMatch(timeString);
    if (matched == null) {
      return null;
    }
    final data = matched.groups([1, 2, 3]);
    final time = Duration(
      minutes: int.tryParse(data[0] ?? '') ?? 0,
      seconds: int.tryParse(data[1] ?? '') ?? 0,
      milliseconds: int.tryParse(data[2] ?? '') ?? 0,
    );

    return time;
  }

  static List<LyricRow> fromString(String rawContent) {
    final rows = rawContent.split('\n');
    final res = <LyricRow>[];

    for (var row in rows) {
      final regExp = RegExp(r'^(\[.*\])\s*(.*)$');
      final matched = regExp.firstMatch(row);
      if (matched == null) {
        continue;
      }
      final data = matched.groups([1, 2]);
      final times = data[0]!.substring(1, data[0]!.length - 1).split('][');
      for (var timeStr in times) {
        final time = _parseTime(timeStr);
        if (time == null) continue;
        res.add(LyricRow(time: time, text: data[1] ?? ''));
      }
    }

    res.sort((a, b) => a.time.compareTo(b.time));

    return res;
  }

  factory LyricRow.fromJson(Map<String, dynamic> json) => _$LyricRowFromJson(json);

  Map<String, dynamic> toJson() => _$LyricRowToJson(this);
}
