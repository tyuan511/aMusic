import 'dart:convert';

import 'package:amusic/models/lyric.dart';
import 'package:amusic/services/lyric_service.dart';
import 'package:flutter_test/flutter_test.dart';

LyricLine _line(int ms, [String text = 'x']) => LyricLine(
  time: Duration(milliseconds: ms),
  text: text,
);

void main() {
  group('LRC', () {
    test('several timestamps on one line produce one line each, sorted', () {
      final lines = Lyric.parseLrc(
        '[00:10.00][00:01.50][01:02.3]chorus\n[00:05.000]verse',
      );
      expect(lines.map((l) => l.time.inMilliseconds), [
        1500,
        5000,
        10000,
        62300,
      ]);
      expect(lines.map((l) => l.text), ['chorus', 'verse', 'chorus', 'chorus']);
    });

    test('1, 2 and 3 digit fractions', () {
      final lines = Lyric.parseLrc('[00:01.5]a\n[00:02.25]b\n[00:03.125]c');
      expect(lines.map((l) => l.time.inMilliseconds), [1500, 2250, 3125]);
    });

    test('metadata tags are skipped and offset is applied', () {
      final lines = Lyric.parseLrc(
        '[ar:Someone]\n[ti:Song]\n[offset:+500]\n[00:02.00]a\n[00:00.20]b',
      );
      expect(lines.map((l) => l.text), ['b', 'a']);
      expect(lines.first.time, Duration.zero);
      expect(lines.last.time, const Duration(milliseconds: 1500));
    });

    test('JSON credit lines become credits, not lyric lines', () {
      final credits = <dynamic>[];
      final doc = [
        jsonEncode({
          't': 0,
          'c': [
            {'tx': '作词: '},
            {'tx': '方文山'},
          ],
        }),
        jsonEncode({
          't': 1000,
          'c': [
            {'tx': '作曲: '},
            {'tx': '周杰伦'},
          ],
        }),
        '[00:12.00]故事的小黄花',
      ].join('\n');
      final lyric = Lyric.parse(lrc: doc);
      credits.addAll(lyric.credits);
      expect(lyric.lines.single.text, '故事的小黄花');
      expect(lyric.credits.map((c) => c.role), ['作词', '作曲']);
      expect(lyric.credits.first.names, ['方文山']);
    });

    test('leading "作词 : x" timed lines move to credits', () {
      final lyric = Lyric.parse(
        lrc:
            '[00:00.00]作词 : 方文山\n[00:01.00]作曲 : 周杰伦 / 某人\n'
            '[00:12.00]故事的小黄花',
      );
      expect(lyric.lines.single.text, '故事的小黄花');
      expect(lyric.credits[1].names, ['周杰伦', '某人']);
    });

    test('a lyric that is only credit-looking lines keeps them', () {
      final lyric = Lyric.parse(lrc: '[00:00.00]作词 : 方文山');
      expect(lyric.lines, hasLength(1));
    });

    test('minutes above 59 are accepted, seconds above 59 rejected', () {
      final lines = Lyric.parseLrc('[75:01.00]long\n[00:61.00]bad');
      expect(lines.single.time, const Duration(minutes: 75, seconds: 1));
    });

    test('pure music flag is kept', () {
      final lyric = Lyric.parse(lrc: '[00:00.00]纯音乐，请欣赏', pureMusic: true);
      expect(lyric.pureMusic, isTrue);
    });
  });

  group('YRC', () {
    test('parses word timing and line duration', () {
      final lyric = Lyric.parse(
        yrc: '[1000,2000](1000,500,0)Hel(1500,500,0)lo (2000,1000,0)world',
        lrc: '[00:01.00]ignored',
      );
      final line = lyric.lines.single;
      expect(line.text, 'Hello world');
      expect(line.duration, const Duration(seconds: 2));
      expect(line.words.map((w) => w.text), ['Hel', 'lo ', 'world']);
      expect(line.words[2].start, const Duration(seconds: 2));
      expect(line.words[2].duration, const Duration(seconds: 1));
      expect(lyric.hasWordTiming, isTrue);
    });

    test('word text may contain parentheses', () {
      final lines = Lyric.parseYrc('[0,1000](0,500,0)(Yeah)(500,500,0) go');
      expect(lines.single.words.map((w) => w.text), ['(Yeah)', ' go']);
    });

    test('word progress', () {
      const word = LyricWord(
        start: Duration(seconds: 1),
        duration: Duration(seconds: 2),
        text: 'a',
      );
      expect(word.progressAt(Duration.zero), 0);
      expect(word.progressAt(const Duration(seconds: 2)), closeTo(0.5, 1e-9));
      expect(word.progressAt(const Duration(seconds: 5)), 1);
    });

    test('falls back to LRC when YRC is unusable', () {
      final lyric = Lyric.parse(yrc: 'garbage', lrc: '[00:01.00]line');
      expect(lyric.lines.single.text, 'line');
      expect(lyric.hasWordTiming, isFalse);
    });

    test('YRC translation comes from ytlrc / tlyric', () {
      final lyric = Lyric.parse(
        yrc: '[1000,1000](1000,1000,0)Hi',
        tlyric: '[00:01.05]你好',
      );
      expect(lyric.lines.single.translation, '你好');
    });
  });

  group('translation matching', () {
    test('exact and near timestamps match', () {
      final main = [_line(10000), _line(20000)];
      final result = Lyric.matchSidecar(main, [
        _line(10000, '一'),
        _line(20400, '二'),
      ]);
      expect(result, ['一', '二']);
    });

    test('the window is capped at 600 ms', () {
      final main = [_line(0), _line(10000)];
      final result = Lyric.matchSidecar(main, [_line(10700, 'late')]);
      expect(result, [null, null]);
    });

    test('the window shrinks to half the gap to the neighbour', () {
      // Gap 400 ms: tolerance 200 ms either side.
      final main = [_line(1000), _line(1400)];
      expect(Lyric.toleranceFor(main, 0), const Duration(milliseconds: 200));
      final result = Lyric.matchSidecar(main, [_line(1250, 'close to 2nd')]);
      expect(result, [null, 'close to 2nd']);
      final miss = Lyric.matchSidecar(main, [_line(1650, 'too far')]);
      expect(miss, [null, null]);
    });

    test('closest candidate wins and placeholders are ignored', () {
      final main = [_line(5000)];
      final result = Lyric.matchSidecar(main, [
        _line(5300, 'far'),
        _line(5050, 'near'),
        _line(5000, '//'),
      ]);
      expect(result, ['near']);
    });
  });

  group('decodeLyricBytes', () {
    const text = '[00:01.00]你好';

    test('UTF-8 with and without BOM', () {
      expect(decodeLyricBytes(utf8.encode(text)), text);
      expect(decodeLyricBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]), text);
    });

    test('UTF-16 LE and BE with BOM', () {
      final le = <int>[0xFF, 0xFE];
      final be = <int>[0xFE, 0xFF];
      for (final unit in text.codeUnits) {
        le.addAll([unit & 0xFF, unit >> 8]);
        be.addAll([unit >> 8, unit & 0xFF]);
      }
      expect(decodeLyricBytes(le), text);
      expect(decodeLyricBytes(be), text);
    });
  });
}
