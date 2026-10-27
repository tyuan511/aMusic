import 'package:amusic/ui/player/lyrics_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stagger', () {
    test('lines above the focus move immediately', () {
      expect(LyricMotion.staggerDelay(3, 5), Duration.zero);
      expect(LyricMotion.staggerDelay(5, 5), Duration.zero);
    });

    test('40 ms per line below, capped', () {
      expect(LyricMotion.staggerDelay(6, 5), const Duration(milliseconds: 40));
      expect(LyricMotion.staggerDelay(8, 5), const Duration(milliseconds: 120));
      expect(
        LyricMotion.staggerDelay(100, 5),
        LyricMotion.staggerStep * LyricMotion.maxStaggerLines,
      );
    });
  });

  group('emphasis', () {
    test('scale and opacity by distance', () {
      expect(LyricMotion.scaleFor(0), 1.0);
      expect(LyricMotion.scaleFor(2), 0.96);
      expect(LyricMotion.opacityFor(0), 1);
      expect(LyricMotion.opacityFor(1), greaterThan(LyricMotion.opacityFor(2)));
      expect(LyricMotion.opacityFor(-3), LyricMotion.opacityFor(3));
      expect(LyricMotion.opacityFor(50), 0.16);
    });

    test('blur is quantised and capped at sigma 4', () {
      expect(LyricMotion.blurLevelFor(0), 0);
      expect(LyricMotion.blurLevelFor(-2), 2);
      expect(LyricMotion.blurLevelFor(30), LyricMotion.blurLevels);
      expect(LyricMotion.sigmaForLevel(LyricMotion.blurLevels), 4);
      expect(LyricMotion.sigmaForLevel(0), 0);
    });
  });

  group('LineSpring', () {
    test('spring parameters', () {
      final spring = LyricMotion.spring;
      expect(spring.mass, 1);
      expect(spring.stiffness, 170);
      // ratio = c / (2 * sqrt(k m))
      expect(spring.damping / (2 * 13.0384), closeTo(0.85, 0.01));
    });

    test('rests until retargeted, then settles on the target', () {
      final line = LineSpring(0);
      expect(line.valueAt(1), 0);
      expect(line.isDoneAt(1), isTrue);
      line.retarget(-100, time: 1);
      expect(line.valueAt(1), closeTo(0, 1e-6));
      expect(line.valueAt(1.1), lessThan(0));
      expect(line.valueAt(3), closeTo(-100, 0.5));
      expect(line.isDoneAt(4), isTrue);
    });

    test('a delayed retarget holds the old value during the delay', () {
      final line = LineSpring(0);
      line.retarget(-50, time: 0, delay: 0.12);
      expect(line.valueAt(0.1), 0);
      expect(line.isDoneAt(0.1), isFalse);
      expect(line.valueAt(0.3), lessThan(0));
    });

    test('retargeting mid-flight keeps the velocity', () {
      final line = LineSpring(0);
      line.retarget(-100, time: 0);
      final before = line.velocityAt(0.1);
      final position = line.valueAt(0.1);
      expect(before, lessThan(0));
      line.retarget(-200, time: 0.1);
      expect(line.valueAt(0.1), closeTo(position, 1e-6));
      expect(line.velocityAt(0.1), closeTo(before, 1e-6));
      expect(line.valueAt(5), closeTo(-200, 0.5));
    });

    test('a delayed retarget mid-flight continues the old trajectory', () {
      final reference = LineSpring(0)..retarget(-100, time: 0);
      final line = LineSpring(0)..retarget(-100, time: 0);
      line.retarget(-200, time: 0.1, delay: 0.08);
      expect(line.valueAt(0.15), closeTo(reference.valueAt(0.15), 1e-6));
      expect(line.valueAt(6), closeTo(-200, 0.5));
    });

    test('jumpTo stops the motion', () {
      final line = LineSpring(0)..retarget(-100, time: 0);
      line.jumpTo(-30);
      expect(line.valueAt(0.5), -30);
      expect(line.isDoneAt(0.5), isTrue);
    });
  });
}
