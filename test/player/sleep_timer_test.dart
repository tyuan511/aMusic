import 'package:amusic/audio/sleep_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late List<double> fades;
  late int expired;
  late SleepTimer timer;

  setUp(() {
    now = DateTime(2024);
    fades = [];
    expired = 0;
    timer = SleepTimer(
      onFade: fades.add,
      onExpire: () => expired++,
      now: () => now,
      autoTick: false,
    );
  });

  test('counts down, fades over the last 8 s and expires', () {
    timer.start(const Duration(minutes: 1));
    expect(timer.remaining.value, const Duration(minutes: 1));
    now = now.add(const Duration(seconds: 30));
    timer.tick();
    expect(timer.remaining.value, const Duration(seconds: 30));
    expect(fades, isEmpty);
    now = now.add(const Duration(seconds: 26));
    timer.tick();
    expect(fades.last, closeTo(0.5, 1e-9));
    now = now.add(const Duration(seconds: 5));
    timer.tick();
    expect(expired, 1);
    expect(timer.remaining.value, isNull);
    expect(timer.active, isFalse);
  });

  test('cancel restores the volume and stops', () {
    timer.start(const Duration(seconds: 10));
    now = now.add(const Duration(seconds: 6));
    timer.tick();
    expect(fades.last, lessThan(1));
    timer.start(null);
    expect(fades.last, 1);
    expect(timer.remaining.value, isNull);
    now = now.add(const Duration(minutes: 1));
    timer.tick();
    expect(expired, 0);
  });

  test('end of track waits for the song to finish', () {
    var trackLeft = const Duration(seconds: 60);
    timer.trackRemaining = () => trackLeft;
    timer.start(const Duration(seconds: 10), endOfTrack: true);
    now = now.add(const Duration(seconds: 5));
    timer.tick();
    // No clock based fade in end-of-track mode.
    expect(fades, isEmpty);
    now = now.add(const Duration(seconds: 6));
    timer.tick();
    expect(expired, 0);
    expect(timer.waitingForTrackEnd, isTrue);
    expect(timer.remaining.value, Duration.zero);
    trackLeft = const Duration(seconds: 2);
    timer.tick();
    expect(fades.last, closeTo(0.25, 1e-9));
    timer.trackEnded();
    expect(expired, 1);
    expect(timer.active, isFalse);
  });

  test('zero with end of track means "after this song"', () {
    timer.start(Duration.zero, endOfTrack: true);
    expect(timer.waitingForTrackEnd, isTrue);
    expect(timer.active, isTrue);
    timer.trackEnded();
    expect(expired, 1);
  });

  test('a track end before the deadline does nothing', () {
    timer.start(const Duration(minutes: 5), endOfTrack: true);
    timer.trackEnded();
    expect(expired, 0);
    expect(timer.active, isTrue);
  });

  test('fadeFactor', () {
    const fade = Duration(seconds: 8);
    expect(fadeFactor(const Duration(seconds: 20), fade), 1);
    expect(fadeFactor(const Duration(seconds: 4), fade), 0.5);
    expect(fadeFactor(Duration.zero, fade), 0);
  });
}
