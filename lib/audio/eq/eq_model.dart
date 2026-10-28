import 'dart:convert';

/// Centre frequencies of the ten bands, in Hz (one octave apart).
const List<double> eqFrequencies = [
  31.25,
  62.5,
  125,
  250,
  500,
  1000,
  2000,
  4000,
  8000,
  16000,
];

const int eqBandCount = 10;

/// Gain range of a band and of the preamp, in dB.
const double eqMaxGain = 12;

/// Q of every band: one octave wide, so neighbouring bands overlap smoothly.
const double eqBandQ = 1.41;

/// "62" / "1k" / "16k" tick labels.
String eqFrequencyLabel(double hz) {
  if (hz >= 1000) {
    final k = hz / 1000;
    return '${k == k.roundToDouble() ? k.round() : k}k';
  }
  return hz == hz.roundToDouble() ? '${hz.round()}' : hz.toStringAsFixed(0);
}

/// A named set of band gains.
class EqPreset {
  const EqPreset({
    required this.id,
    required this.name,
    required this.gains,
    this.builtIn = true,
  });

  final String id;
  final String name;
  final List<double> gains;
  final bool builtIn;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'gains': gains};

  static EqPreset? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final gains = json['gains'];
    if (id is! String || name is! String || gains is! List) return null;
    if (gains.length != eqBandCount) return null;
    return EqPreset(
      id: id,
      name: name,
      builtIn: false,
      gains: [for (final g in gains) clampGain(g is num ? g.toDouble() : 0)],
    );
  }
}

double clampGain(double db) => db.clamp(-eqMaxGain, eqMaxGain).toDouble();

/// The preamp can cut by [eqMaxGain] but only boost a little: a big
/// boost would eat into the limiter's headroom.
const double eqMaxPreamp = 6;

double clampPreamp(double db) => db.clamp(-eqMaxGain, eqMaxPreamp).toDouble();

/// Built in presets.
///
/// The curves are the ones Apple Music ships (read from Music.app's own
/// `EQ preset` objects), which share our ten bands (32 Hz .. 16 kHz). They
/// are gentle, musically tuned shapes that rarely go beyond +-5 dB, unlike
/// the extreme Winamp / VLC era tables.
class EqPresets {
  EqPresets._();

  static const flat = EqPreset(
    id: 'flat',
    name: '平直',
    gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  static const List<EqPreset> all = [
    flat,
    EqPreset(
      id: 'bass',
      name: '低音增强',
      gains: [5.5, 4.25, 3.5, 2.5, 1.25, 0, 0, 0, 0, 0],
    ),
    EqPreset(
      id: 'treble',
      name: '高音增强',
      gains: [0, 0, 0, 0, 0, 1.25, 2.5, 3.5, 4.25, 5.5],
    ),
    EqPreset(
      id: 'vocal',
      name: '人声增强',
      gains: [-1.5, -3, -3, 1.5, 3.75, 3.75, 3, 1.5, 0, -1.5],
    ),
    EqPreset(
      id: 'pop',
      name: '流行',
      gains: [-1.5, -1, 0, 2, 4, 4, 2, 0, -1, -1.5],
    ),
    EqPreset(
      id: 'rock',
      name: '摇滚',
      gains: [5, 4, 3, 1.5, -0.5, -1, 0.5, 2.5, 3.5, 4.5],
    ),
    EqPreset(
      id: 'electronic',
      name: '电子',
      gains: [4.25, 3.8, 1.2, 0, -2.15, 2.25, 0.85, 1.25, 3.95, 4.8],
    ),
    EqPreset(
      id: 'dance',
      name: '舞曲',
      gains: [3.57, 6.55, 4.99, 0, 1.92, 3.65, 5.15, 4.54, 3.59, 0],
    ),
    EqPreset(
      id: 'hiphop',
      name: '嘻哈',
      gains: [5, 4.25, 1.5, 3, -1, -1, 1.5, -0.5, 2, 3],
    ),
    EqPreset(
      id: 'rnb',
      name: 'R&B',
      gains: [2.62, 6.92, 5.65, 1.33, -2.19, -1.5, 2.32, 2.65, 3, 3.75],
    ),
    EqPreset(
      id: 'jazz',
      name: '爵士',
      gains: [4, 3, 1.5, 2.25, -1.5, -1.5, 0, 1.5, 3, 3.75],
    ),
    EqPreset(
      id: 'classical',
      name: '古典',
      gains: [4.75, 3.75, 3, 2.5, -1.5, -1.5, 0, 2.25, 3.25, 3.75],
    ),
    EqPreset(
      id: 'piano',
      name: '钢琴',
      gains: [3, 2, 0, 2.5, 3, 1.5, 3.5, 4.5, 3, 3.5],
    ),
    EqPreset(
      id: 'acoustic',
      name: '原声',
      gains: [5, 4.9, 3.95, 1.05, 2.15, 1.75, 3.5, 4.1, 3.55, 2.15],
    ),
    EqPreset(
      id: 'latin',
      name: '拉丁',
      gains: [4.5, 3, 0, 0, -1.5, -1.5, -1.5, 0, 3, 4.5],
    ),
    EqPreset(
      id: 'lounge',
      name: '休闲',
      gains: [-3, -1.5, -0.5, 1.5, 4, 2.5, 0, -1.5, 2, 1],
    ),
    EqPreset(
      id: 'deep',
      name: '低沉',
      gains: [4.95, 3.55, 1.75, 1, 2.85, 2.5, 1.45, -2.15, -3.55, -4.6],
    ),
    EqPreset(
      id: 'loudness',
      name: '响度',
      gains: [6, 4, 0, 0, -2, 0, -1, -5, 5, 1],
    ),
    EqPreset(
      id: 'spoken',
      name: '朗读',
      gains: [-3.46, -0.47, 0, 0.69, 3.46, 4.61, 4.84, 4.28, 2.54, 0],
    ),
    EqPreset(
      id: 'bassCut',
      name: '低音减弱',
      gains: [-5.5, -4.25, -3.5, -2.5, -1.25, 0, 0, 0, 0, 0],
    ),
    EqPreset(
      id: 'trebleCut',
      name: '高音减弱',
      gains: [0, 0, 0, 0, 0, -1.25, -2.5, -3.5, -4.25, -5.5],
    ),
    EqPreset(
      id: 'smallSpeakers',
      name: '小型扬声器',
      gains: [5.5, 4.25, 3.5, 2.5, 1.25, 0, -1.25, -2.5, -3.5, -4.25],
    ),
  ];

  static EqPreset? byId(String? id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}

/// One peaking filter: what a libavfilter `equalizer` stage does.
class EqBand {
  const EqBand(this.freq, this.q, this.gain);

  final double freq;
  final double q;
  final double gain;
}

/// A one tap sound effect ("音效"): peaking filters shaped for a purpose and,
/// for the spatial ones, DSP that only the Rust engine can run.
///
/// An effect and the user's equalizer are mutually exclusive: choosing one
/// switches the other off.
class SoundEffect {
  const SoundEffect({
    required this.id,
    required this.name,
    required this.description,
    this.bands = const [],
    this.dsp = 0,
  });

  final String id;
  final String name;
  final String description;
  final List<EqBand> bands;

  /// The engine's DSP effect: 0 none, 1 3D surround, 2 360 rotation,
  /// 3 LiveHouse, 4 harmonic exciter.
  final int dsp;
}

class SoundEffects {
  SoundEffects._();

  /// In the order of the card grid (two per row).
  static const List<SoundEffect> all = [
    SoundEffect(
      id: 'surround3d',
      name: '3D环绕',
      description: '戴上耳机，沉浸式拥抱四方涌来的音乐',
      dsp: 1,
    ),
    SoundEffect(
      id: 'clearVocal',
      name: '清澈人声',
      description: '或低沉或嘹亮或婉转，感受人声之美',
      bands: [
        EqBand(100, 0.8, -2.5),
        EqBand(250, 1.2, -2.5),
        EqBand(500, 1.2, -1.5),
        EqBand(1800, 1.0, 2),
        EqBand(3200, 1.2, 3.5),
        EqBand(6000, 1.5, 1.5),
        EqBand(10000, 0.9, 2),
      ],
    ),
    SoundEffect(
      id: 'hiResVocal',
      name: '高解析人声',
      description: '超强的解析力还原甜美人声与通透高音',
      bands: [
        EqBand(200, 1.0, -1.5),
        EqBand(2500, 1.1, 3),
        EqBand(4500, 1.3, 3.5),
        EqBand(8000, 1.0, 3),
        EqBand(14000, 0.8, 4),
      ],
      // Plus harmonic enhancement where the engine can do it.
      dsp: 4,
    ),
    SoundEffect(
      id: 'rotate360',
      name: '360°环绕',
      description: '精密算法，360°旋转，音乐行星常伴左右',
      dsp: 2,
    ),
    SoundEffect(
      id: 'superBass',
      name: '超重低音',
      description: '带来更加深邃、浑厚、富有弹性的低音',
      bands: [
        EqBand(40, 0.9, 6),
        EqBand(70, 1.0, 5.5),
        EqBand(115, 1.1, 3),
        EqBand(230, 1.0, -1.5),
        EqBand(12000, 0.8, 1),
      ],
    ),
    SoundEffect(
      id: 'liveHouse',
      name: 'LiveHouse现场',
      description: '仿佛置身于一个乐迷聚集的小型音乐厅',
      dsp: 3,
    ),
  ];

  static SoundEffect? byId(String? id) {
    for (final effect in all) {
      if (effect.id == id) return effect;
    }
    return null;
  }
}

/// The ten user bands as [EqBand]s (zero gain bands are skipped).
List<EqBand> eqBands(List<double> gains) => [
  for (var i = 0; i < eqBandCount; i++)
    if (gains[i].abs() >= 0.05) EqBand(eqFrequencies[i], eqBandQ, gains[i]),
];

/// The equalizer's live settings.
class EqSettings {
  const EqSettings({
    this.enabled = false,
    this.preamp = 0,
    this.gains = _flat,
    this.presetId = 'flat',
    this.effectEnabled = false,
    this.effectId,
  });

  static const List<double> _flat = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

  final bool enabled;

  /// Extra gain applied before the bands, in dB.
  final double preamp;
  final List<double> gains;

  /// Id of the preset [gains] currently equals, `null` once edited by hand.
  final String? presetId;

  /// Whether the one tap sound effect is on, and which one.
  final bool effectEnabled;
  final String? effectId;

  SoundEffect? get effect => effectEnabled ? SoundEffects.byId(effectId) : null;

  bool get isFlat => gains.every((g) => g.abs() < 0.05) && preamp.abs() < 0.05;

  /// `true` when the filter chain would change the signal at all.
  bool get isActive => effect != null || (enabled && !isFlat);

  EqSettings copyWith({
    bool? enabled,
    double? preamp,
    List<double>? gains,
    Object? presetId = _keep,
    bool? effectEnabled,
    Object? effectId = _keep,
  }) => EqSettings(
    enabled: enabled ?? this.enabled,
    preamp: preamp ?? this.preamp,
    gains: gains ?? this.gains,
    presetId: identical(presetId, _keep) ? this.presetId : presetId as String?,
    effectEnabled: effectEnabled ?? this.effectEnabled,
    effectId: identical(effectId, _keep) ? this.effectId : effectId as String?,
  );

  static const Object _keep = Object();

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'preamp': preamp,
    'gains': gains,
    'preset': presetId,
    'effectEnabled': effectEnabled,
    'effect': effectId,
  };

  static EqSettings fromJson(Object? json) {
    if (json is! Map) return const EqSettings();
    final gains = json['gains'];
    final effectOn = json['effectEnabled'] == true;
    return EqSettings(
      // An effect and the equalizer never run together.
      enabled: json['enabled'] == true && !effectOn,
      preamp: clampPreamp((json['preamp'] as num?)?.toDouble() ?? 0),
      gains: gains is List && gains.length == eqBandCount
          ? [for (final g in gains) clampGain(g is num ? g.toDouble() : 0)]
          : _flat,
      presetId: json['preset'] as String?,
      effectEnabled: effectOn,
      effectId: json['effect'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EqSettings &&
      other.enabled == enabled &&
      other.preamp == preamp &&
      other.presetId == presetId &&
      other.effectEnabled == effectEnabled &&
      other.effectId == effectId &&
      _listEquals(other.gains, gains);

  @override
  int get hashCode => Object.hash(
    enabled,
    preamp,
    presetId,
    effectEnabled,
    effectId,
    Object.hashAll(gains),
  );
}

bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String encodeCustomPresets(List<EqPreset> presets) =>
    jsonEncode([for (final p in presets) p.toJson()]);

List<EqPreset> decodeCustomPresets(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [for (final item in decoded) ?EqPreset.fromJson(item)];
  } on FormatException {
    return const [];
  }
}
