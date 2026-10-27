/// Formatting helpers shared by the UI.
extension DurationFormat on Duration {
  /// `m:ss`, or `h:mm:ss` for tracks longer than an hour.
  String get clock {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    final seconds = inSeconds.remainder(60);
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
  }

  /// `-m:ss`, used for the remaining time next to a seek bar.
  String get remainingClock => '-${(isNegative ? Duration.zero : this).clock}';
}

extension CountFormat on int {
  /// `1.2万` / `3.4亿` for Chinese users, plain numbers below 10000.
  String get compact {
    if (this < 10000) return toString();
    if (this < 100000000) {
      final value = this / 10000;
      return '${value >= 100 ? value.round() : value.toStringAsFixed(1)}万';
    }
    final value = this / 100000000;
    return '${value >= 100 ? value.round() : value.toStringAsFixed(1)}亿';
  }
}

extension DateTimeFormat on DateTime {
  String get date => '$year-${_two(month)}-${_two(day)}';

  String get dateTime => '$date ${_two(hour)}:${_two(minute)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// Appends NetEase's image resize parameter so we never download a 1000px
/// cover for a 44px thumbnail.
String sizedImage(String? url, {int size = 200}) {
  if (url == null || url.isEmpty) return '';
  if (url.contains('param=')) return url;
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}param=${size}y$size';
}
