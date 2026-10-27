import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Sends one play report; throws when it could not be delivered.
typedef ScrobbleSender = Future<void> Function(
  int songId,
  int? sourceId,
  int seconds,
);

/// One pending play report.
class ScrobbleEntry {
  const ScrobbleEntry({
    required this.songId,
    required this.seconds,
    this.sourceId,
  });

  final int songId;
  final int? sourceId;
  final int seconds;

  Map<String, dynamic> toJson() => {
    'id': songId,
    if (sourceId != null) 'src': sourceId,
    's': seconds,
  };

  static ScrobbleEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final seconds = json['s'];
    if (id is! int || seconds is! int) return null;
    final source = json['src'];
    return ScrobbleEntry(
      songId: id,
      seconds: seconds,
      sourceId: source is int ? source : null,
    );
  }
}

/// Persistent FIFO of play reports (`scrobble.queue`, at most [maxEntries]).
///
/// Reports are delivered head first, one at a time. A failed head stays at
/// the head and is retried with a growing back-off, so going offline never
/// drops history and never reorders it.
class ScrobbleQueue {
  ScrobbleQueue({
    required this._prefs,
    required this._send,
    this.retryDelay = const Duration(seconds: 30),
  }) {
    _entries.addAll(_read());
  }

  static const String prefsKey = 'scrobble.queue';
  static const int maxEntries = 50;

  final SharedPreferences _prefs;
  final ScrobbleSender _send;

  /// First retry delay; doubles per consecutive failure up to 10 min.
  final Duration retryDelay;

  final List<ScrobbleEntry> _entries = [];
  bool _flushing = false;
  int _failures = 0;
  Timer? _retry;
  bool _disposed = false;

  List<ScrobbleEntry> get pending => List.unmodifiable(_entries);

  List<ScrobbleEntry> _read() {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?ScrobbleEntry.fromJson(item)]
          .take(maxEntries)
          .toList();
    } on FormatException {
      return const [];
    }
  }

  void _persist() {
    if (_entries.isEmpty) {
      _prefs.remove(prefsKey);
    } else {
      _prefs.setString(
        prefsKey,
        jsonEncode([for (final entry in _entries) entry.toJson()]),
      );
    }
  }

  /// Queues a report and tries to deliver right away. The oldest entries are
  /// dropped beyond [maxEntries].
  void add(ScrobbleEntry entry) {
    if (_disposed) return;
    _entries.add(entry);
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    _persist();
    unawaited(flush());
  }

  /// Delivers everything pending. Returns once the queue is empty or the
  /// head failed (a retry is scheduled then).
  Future<void> flush() async {
    if (_flushing || _disposed) return;
    _flushing = true;
    _retry?.cancel();
    try {
      while (_entries.isNotEmpty && !_disposed) {
        final head = _entries.first;
        try {
          await _send(head.songId, head.sourceId, head.seconds);
        } on Object {
          _failures++;
          _scheduleRetry();
          return;
        }
        _failures = 0;
        if (_entries.isNotEmpty && identical(_entries.first, head)) {
          _entries.removeAt(0);
        } else {
          _entries.remove(head);
        }
        _persist();
      }
    } finally {
      _flushing = false;
    }
  }

  void _scheduleRetry() {
    if (_disposed) return;
    final factor = 1 << (_failures - 1).clamp(0, 5);
    var delay = retryDelay * factor;
    if (delay > const Duration(minutes: 10)) {
      delay = const Duration(minutes: 10);
    }
    _retry?.cancel();
    _retry = Timer(delay, () => unawaited(flush()));
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
  }
}
