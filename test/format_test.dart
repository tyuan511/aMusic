import 'package:amusic/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clock formats mm:ss and h:mm:ss', () {
    expect(const Duration(seconds: 65).clock, '1:05');
    expect(const Duration(minutes: 12, seconds: 3).clock, '12:03');
    expect(const Duration(hours: 1, minutes: 2, seconds: 3).clock, '1:02:03');
    expect(Duration.zero.clock, '0:00');
  });

  test('compact counts use 万 / 亿', () {
    expect(999.compact, '999');
    expect(12345.compact, '1.2万');
    expect(1200000.compact, '120万');
    expect(350000000.compact, '3.5亿');
  });

  test('sizedImage appends the resize parameter once', () {
    expect(
      sizedImage('https://a/b.jpg', size: 120),
      'https://a/b.jpg?param=120y120',
    );
    expect(
      sizedImage('https://a/b.jpg?x=1', size: 120),
      'https://a/b.jpg?x=1&param=120y120',
    );
    expect(
      sizedImage('https://a/b.jpg?param=50y50'),
      'https://a/b.jpg?param=50y50',
    );
    expect(sizedImage(null), '');
  });

  test('date formatting is zero padded', () {
    expect(DateTime(2026, 3, 4, 5, 6).dateTime, '2026-03-04 05:06');
  });
}
