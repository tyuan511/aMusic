import 'package:amusic/audio/eq/eq_dsp.dart';
import 'package:amusic/audio/eq/eq_model.dart';
import 'package:amusic/audio/eq/eq_service.dart';
import 'package:amusic/core/prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EqFilterGraph', () {
    test('is off when bypassed or flat', () {
      expect(EqFilterGraph.build(const EqSettings()), EqEngineConfig.off);
      expect(
        EqFilterGraph.build(
          const EqSettings(gains: [3, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        ),
        EqEngineConfig.off,
      );
      expect(
        EqFilterGraph.build(const EqSettings(enabled: true)),
        EqEngineConfig.off,
      );
    });

    test('hands the engine the bands and the preamp', () {
      final config = EqFilterGraph.build(
        const EqSettings(enabled: true, gains: [6, 0, 0, 0, 0, 0, 0, 0, 0, -3]),
      );
      expect(config.bands.where((b) => b.gain != 0).length, 2);
      expect(config.bands.first.freq, 31.25);
      expect(config.bands.first.gain, 6);
      expect(config.bands.last.freq, 16000);
      expect(config.bands.last.gain, -3);
      expect(config.preampDb, 0);
    });

    test('a cut alone needs no headroom', () {
      const List<double> gains = [-6, -3, 0, 0, 0, 0, 0, 0, 0, 0];
      expect(EqFilterGraph.peakBoostDb(eqBands(gains)), 0);
    });

    test('preamp alone is passed on with flat bands', () {
      final config = EqFilterGraph.build(
        const EqSettings(enabled: true, preamp: -4),
      );
      expect(config.bands.every((b) => b.gain == 0), isTrue);
      expect(config.preampDb, -4);
    });

    test('preamp is clamped to what the engine can do without clipping', () {
      expect(clampPreamp(40), eqMaxPreamp);
      expect(clampPreamp(-40), -eqMaxGain);
    });
  });

  group('sound effects', () {
    test('there are six, in the order of the card grid', () {
      expect(SoundEffects.all.map((e) => e.name), [
        '3D环绕',
        '清澈人声',
        '高解析人声',
        '360°环绕',
        '超重低音',
        'LiveHouse现场',
      ]);
      expect(SoundEffects.all.map((e) => e.id).toSet().length, 6);
    });

    test('an EQ-only effect reaches the engine as bands', () {
      const settings = EqSettings(effectEnabled: true, effectId: 'superBass');
      final config = EqFilterGraph.build(settings);
      final effect = SoundEffects.byId('superBass')!;
      expect(config.bands.length, effect.bands.length);
      expect(config.bands.any((b) => b.freq == 40 && b.gain == 6), isTrue);
      expect(config.effect, 0);
    });

    test('a DSP effect reaches the engine as an id, with no bands', () {
      const expected = {'surround3d': 1, 'rotate360': 2, 'liveHouse': 3};
      for (final entry in expected.entries) {
        final config = EqFilterGraph.build(
          EqSettings(effectEnabled: true, effectId: entry.key),
        );
        expect(config.effect, entry.value, reason: entry.key);
        expect(config.bands, isEmpty, reason: entry.key);
      }
    });

    test('hi-res vocal is EQ plus the exciter', () {
      final config = EqFilterGraph.build(
        const EqSettings(effectEnabled: true, effectId: 'hiResVocal'),
      );
      expect(config.effect, 4);
      expect(config.bands, isNotEmpty);
    });

    test('the effect wins over the equalizer: they never stack', () {
      const settings = EqSettings(
        enabled: true,
        preamp: 4,
        gains: [0, 0, 0, 0, 0, 3, 0, 0, 0, 0],
        effectEnabled: true,
        effectId: 'clearVocal',
      );
      final bands = EqFilterGraph.bandsOf(settings);
      final effect = SoundEffects.byId('clearVocal')!;
      expect(bands.length, effect.bands.length);
      expect(bands.any((b) => b.freq == 1000), isFalse);
      expect(EqFilterGraph.preampOf(settings), 0);
    });

    test('a disabled or unknown effect does nothing', () {
      expect(
        EqFilterGraph.build(
          const EqSettings(effectEnabled: false, effectId: 'superBass'),
        ),
        EqEngineConfig.off,
      );
      expect(
        EqFilterGraph.build(
          const EqSettings(effectEnabled: true, effectId: 'nope'),
        ),
        EqEngineConfig.off,
      );
    });

    test('settings saved with both switches on load as effect only', () {
      final loaded = EqSettings.fromJson({
        'enabled': true,
        'effectEnabled': true,
        'effect': 'liveHouse',
      });
      expect(loaded.enabled, isFalse);
      expect(loaded.effect?.id, 'liveHouse');
    });
  });

  group('responseDb', () {
    test('a single band peaks at its own gain on its own frequency', () {
      final gains = List.filled(eqBandCount, 0.0)..[5] = 6;
      expect(responseDb(eqBands(gains), 1000), closeTo(6, 0.05));
      expect(responseDb(eqBands(gains), 100), lessThan(1));
      expect(responseDb(eqBands(gains), 10000), lessThan(1));
    });

    test('flat curve is 0 dB everywhere', () {
      final gains = List.filled(eqBandCount, 0.0);
      for (final hz in [20.0, 440.0, 5000.0, 20000.0]) {
        expect(responseDb(eqBands(gains), hz), 0);
      }
    });
  });

  group('EqSettings', () {
    test('json round trip clamps and falls back', () {
      final back = EqSettings.fromJson(
        const EqSettings(
          enabled: true,
          preamp: -2,
          gains: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          presetId: null,
        ).toJson(),
      );
      expect(back.enabled, isTrue);
      expect(back.gains[9], 10);
      expect(
        EqSettings.fromJson({'gains': List.filled(10, 99)}).gains.first,
        eqMaxGain,
      );
      expect(
        EqSettings.fromJson({
          'gains': [1],
        }).isFlat,
        isTrue,
      );
      expect(EqSettings.fromJson('garbage').enabled, isFalse);
    });

    test('every built in preset has a gain for each band', () {
      for (final preset in EqPresets.all) {
        expect(preset.gains, hasLength(eqBandCount), reason: preset.id);
        expect(preset.gains.every((g) => g.abs() <= eqMaxGain), isTrue);
      }
    });
  });

  group('EqService', () {
    late List<EqEngineConfig> applied;

    Future<EqService> make([Map<String, Object> seed = const {}]) async {
      SharedPreferences.setMockInitialValues(seed);
      final prefs = await SharedPreferences.getInstance();
      applied = [];
      return EqService(
        prefs: prefs,
        sink: (config) async => applied.add(config),
        applyInterval: const Duration(milliseconds: 5),
      );
    }

    test('starts with an empty chain', () async {
      final eq = await make();
      expect(applied, [EqEngineConfig.off]);
      eq.dispose();
    });

    test('a preset switches the equalizer on immediately', () async {
      final eq = await make();
      eq.applyPreset(EqPresets.byId('bass')!);
      await Future<void>.delayed(Duration.zero);
      expect(eq.settings.enabled, isTrue);
      expect(eq.settings.presetId, 'bass');
      expect(applied.last.bands, isNotEmpty);
      eq.dispose();
    });

    test('dragging coalesces filter updates and drops the preset id', () async {
      final eq = await make();
      eq.applyPreset(EqPresets.flat);
      applied.clear();
      for (var i = 1; i <= 8; i++) {
        eq.setBand(2, i.toDouble());
      }
      expect(eq.settings.presetId, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(applied, hasLength(1));
      expect(applied.single.bands.single.gain, 8);
      eq.dispose();
    });

    test('settings and custom presets survive a restart', () async {
      final eq = await make();
      eq.setEnabled(true);
      eq.setBand(0, 4);
      final saved = eq.saveCustom('我的');
      eq.flush();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefsKeys.eq), isNotNull);
      eq.dispose();

      final again = EqService(prefs: prefs, sink: (_) async {});
      expect(again.settings.enabled, isTrue);
      expect(again.settings.gains[0], 4);
      expect(again.settings.presetId, saved.id);
      expect(again.value.custom.single.name, '我的');
      again.deleteCustom(saved.id);
      expect(again.value.custom, isEmpty);
      expect(again.settings.presetId, isNull);
      again.dispose();
    });

    test('selecting an effect switches it on and survives a restart', () async {
      final eq = await make();
      eq.selectEffect('clearVocal');
      expect(eq.settings.effectEnabled, isTrue);
      expect(applied.last.bands, isNotEmpty);
      eq.setEffectEnabled(false);
      expect(eq.settings.effectId, 'clearVocal');
      expect(applied.last, EqEngineConfig.off);
      eq.setEffectEnabled(true);
      eq.flush();
      final prefs = await SharedPreferences.getInstance();
      eq.dispose();

      final again = EqService(prefs: prefs, sink: (_) async {});
      expect(again.settings.effect?.id, 'clearVocal');
      again.dispose();
    });

    test('effect and equalizer switch each other off', () async {
      final eq = await make();
      eq.applyPreset(EqPresets.byId('rock')!);
      expect(eq.settings.enabled, isTrue);

      eq.selectEffect('liveHouse');
      expect(eq.settings.effectEnabled, isTrue);
      expect(eq.settings.enabled, isFalse, reason: 'effect switches EQ off');

      eq.setBand(3, 4);
      expect(eq.settings.enabled, isTrue);
      expect(eq.settings.effectEnabled, isFalse, reason: 'EQ edit ends effect');

      eq.selectEffect('superBass');
      eq.setEnabled(true);
      expect(eq.settings.effectEnabled, isFalse);

      eq.setEffectEnabled(true);
      expect(eq.settings.enabled, isFalse);
      eq.applyPreset(EqPresets.byId('pop')!);
      expect(eq.settings.effectEnabled, isFalse);
      eq.dispose();
    });

    test('turning the effect on with none chosen picks the first', () async {
      final eq = await make();
      eq.setEffectEnabled(true);
      expect(eq.settings.effectId, SoundEffects.all.first.id);
      eq.dispose();
    });

    test('reset returns to a flat curve but keeps the on/off state', () async {
      final eq = await make();
      eq.applyPreset(EqPresets.byId('rock')!);
      eq.reset();
      expect(eq.settings.isFlat, isTrue);
      expect(eq.settings.enabled, isTrue);
      expect(eq.settings.presetId, 'flat');
      eq.dispose();
    });
  });
}
