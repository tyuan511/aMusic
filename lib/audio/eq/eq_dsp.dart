import 'dart:math' as math;

import 'eq_model.dart';

/// Sample rate the on screen curve is computed at. The real filters adapt to
/// the stream's rate; the difference only shows above ~10 kHz.
const double _curveSampleRate = 48000;

/// What the audio engine has to apply for a given [EqSettings].
class EqEngineConfig {
  const EqEngineConfig({
    this.bands = const [],
    this.preampDb = 0,
    this.effect = 0,
    this.effectLoudnessDb = 0,
  });

  /// The filter stages the engine runs as peaking biquads.
  final List<EqBand> bands;

  /// The user's preamp alone; the engine's limiter replaces any headroom.
  final double preampDb;

  /// The engine's DSP effect (0 none); see [SoundEffect.dsp].
  final int effect;

  /// Independent gain for a sound effect, in dB. This is kept separate from
  /// [preampDb] so the EQ preamp remains meaningful when the effect is off.
  final double effectLoudnessDb;

  static const EqEngineConfig off = EqEngineConfig();

  @override
  bool operator ==(Object other) =>
      other is EqEngineConfig &&
      other.preampDb == preampDb &&
      other.effect == effect &&
      other.effectLoudnessDb == effectLoudnessDb &&
      _sameBands(other.bands, bands);

  @override
  int get hashCode =>
      Object.hash(preampDb, effect, effectLoudnessDb, Object.hashAll(bands));

  @override
  String toString() =>
      'EqEngineConfig(${bands.length} bands, ${preampDb}dB, effect ${effectLoudnessDb}dB)';

  static bool _sameBands(List<EqBand> a, List<EqBand> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].freq != b[i].freq ||
          a[i].q != b[i].q ||
          a[i].gain != b[i].gain) {
        return false;
      }
    }
    return true;
  }
}

/// Turns [EqSettings] into what the Rust engine applies: ten RBJ peaking
/// biquads, the preamp and an optional DSP effect.
class EqFilterGraph {
  EqFilterGraph._();

  static EqEngineConfig build(EqSettings settings) {
    final bands = bandsOf(settings);
    final preamp = preampOf(settings);
    final dsp = settings.effect?.dsp ?? 0;
    final effectLoudness = effectLoudnessOf(settings);
    if (bands.isEmpty &&
        preamp.abs() < 0.05 &&
        dsp == 0 &&
        effectLoudness.abs() < 0.05) {
      return EqEngineConfig.off;
    }
    return EqEngineConfig(
      bands: bands,
      preampDb: preamp,
      effect: dsp,
      effectLoudnessDb: effectLoudness,
    );
  }

  /// The filter stages: the sound effect's, or else the user's own bands. The
  /// two are mutually exclusive, and an effect wins if both are somehow on.
  static List<EqBand> bandsOf(EqSettings settings) {
    final effect = settings.effect;
    if (effect != null) return effect.bands;
    return settings.enabled ? eqBands(settings.gains) : const [];
  }

  /// The user's preamp; an effect has none.
  static double preampOf(EqSettings settings) =>
      settings.effect == null && settings.enabled ? settings.preamp : 0;

  static double effectLoudnessOf(EqSettings settings) =>
      settings.effect == null ? 0 : settings.effectLoudness;

  /// Largest positive combined response of [bands], in dB (never negative).
  static double peakBoostDb(List<EqBand> bands) {
    var peak = 0.0;
    for (final hz in _probeFrequencies) {
      peak = math.max(peak, responseDb(bands, hz));
    }
    return peak;
  }

  static final List<double> _probeFrequencies = [
    for (var i = 0; i <= 96; i++) 20 * math.pow(1000, i / 96).toDouble(),
  ];
}

/// Combined magnitude response, in dB, of [bands] at [hz]: the product of the
/// cascaded RBJ peaking biquads, matching what the audio goes through.
double responseDb(List<EqBand> bands, double hz) {
  var db = 0.0;
  for (final b in bands) {
    db += _peakingDb(b.freq, b.gain, b.q, hz);
  }
  return db;
}

/// Magnitude of one RBJ "peakingEQ" biquad at [hz], in dB.
double _peakingDb(double f0, double gainDb, double q, double hz) {
  final a = math.pow(10, gainDb / 40).toDouble();
  final w0 = 2 * math.pi * f0 / _curveSampleRate;
  final alpha = math.sin(w0) / (2 * q);
  final cosW0 = math.cos(w0);
  final b0 = 1 + alpha * a;
  final b1 = -2 * cosW0;
  final b2 = 1 - alpha * a;
  final a0 = 1 + alpha / a;
  final a1 = -2 * cosW0;
  final a2 = 1 - alpha / a;

  final w = 2 * math.pi * hz / _curveSampleRate;
  final cosW = math.cos(w);
  final cos2W = math.cos(2 * w);
  final sinW = math.sin(w);
  final sin2W = math.sin(2 * w);
  final numRe = b0 + b1 * cosW + b2 * cos2W;
  final numIm = -(b1 * sinW + b2 * sin2W);
  final denRe = a0 + a1 * cosW + a2 * cos2W;
  final denIm = -(a1 * sinW + a2 * sin2W);
  final num = numRe * numRe + numIm * numIm;
  final den = denRe * denRe + denIm * denIm;
  return 10 * math.log(num / den) / math.ln10;
}
