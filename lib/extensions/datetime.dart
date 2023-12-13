extension IntToDatetime on int {
  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(this);
}

extension FormateDatetime on DateTime {
  String formate() {
    final year = this.year;
    final month = this.month.toString().padLeft(2, '0');
    final day = this.day.toString().padLeft(2, '0');
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    final second = this.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}
