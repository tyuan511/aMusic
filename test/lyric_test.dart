import 'package:amusic/models/lyric.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Lyric.parse', () {
    test('parses timestamps and sorts them', () {
      final lyric = Lyric.parse(lrc: '[00:12.50]second\n[00:01.00]first\n');
      expect(lyric.lines.length, 2);
      expect(lyric.lines.first.text, 'first');
      expect(lyric.lines.first.time, const Duration(seconds: 1));
      expect(
        lyric.lines.last.time,
        const Duration(seconds: 12, milliseconds: 500),
      );
    });

    test('handles three digit milliseconds and shared tags', () {
      final lyric = Lyric.parse(lrc: '[00:01.234][00:05.678]repeated');
      expect(lyric.lines.length, 2);
      expect(
        lyric.lines[0].time,
        const Duration(seconds: 1, milliseconds: 234),
      );
      expect(
        lyric.lines[1].time,
        const Duration(seconds: 5, milliseconds: 678),
      );
    });

    test('merges translations by timestamp', () {
      final lyric = Lyric.parse(
        lrc: '[00:10.00]hello\n[00:20.00]world',
        tlyric: '[00:10.00]你好\n',
      );
      expect(lyric.hasTranslation, isTrue);
      expect(lyric.lines[0].translation, '你好');
      expect(lyric.lines[1].translation, isNull);
    });

    test('skips leading empty lines', () {
      final lyric = Lyric.parse(
        lrc: '[00:00.000]\n[00:01.000]\n[00:02.000]text',
      );
      expect(lyric.lines.length, 1);
      expect(lyric.lines.single.text, 'text');
    });

    test('ignores malformed tags', () {
      final lyric = Lyric.parse(
        lrc: 'not a lyric line\n[abc]nope\n[00:03.00]ok',
      );
      expect(lyric.lines.map((line) => line.text), ['ok']);
    });
  });

  group('Lyric.lineIndexAt', () {
    final lyric = Lyric.parse(lrc: '[00:00.00]a\n[00:05.00]b\n[00:10.00]c');

    test('returns -1 before the first line', () {
      expect(lyric.lineIndexAt(Duration.zero), 0);
    });

    test('finds the active line', () {
      expect(lyric.lineIndexAt(const Duration(seconds: 6)), 1);
      expect(
        lyric.lineIndexAt(const Duration(seconds: 9, milliseconds: 999)),
        1,
      );
      expect(lyric.lineIndexAt(const Duration(seconds: 30)), 2);
    });

    test('empty lyric has no active line', () {
      expect(Lyric.empty.lineIndexAt(const Duration(seconds: 5)), -1);
    });
  });
}
