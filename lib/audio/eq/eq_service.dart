// ignore_for_file: prefer_initializing_formals
// Named parameters cannot start with an underscore, so the private fields are
// assigned in the initializer list.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/prefs.dart';
import 'eq_dsp.dart';
import 'eq_model.dart';

/// Applies a filter chain to the audio engine.
typedef AudioFilterSink = Future<void> Function(EqEngineConfig config);

class EqState {
  const EqState({this.settings = const EqSettings(), this.custom = const []});

  final EqSettings settings;
  final List<EqPreset> custom;

  List<EqPreset> get presets => [...EqPresets.all, ...custom];

  EqPreset? get activePreset {
    final id = settings.presetId;
    if (id == null) return null;
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  EqState copyWith({EqSettings? settings, List<EqPreset>? custom}) => EqState(
    settings: settings ?? this.settings,
    custom: custom ?? this.custom,
  );
}

/// The equalizer. Edits are published at once (the UI stays live while a fader
/// is dragged) while the engine filter is re-applied at most every
/// [applyInterval]; the settings are persisted when the drag settles.
class EqService extends ValueNotifier<EqState> {
  EqService({
    required SharedPreferences prefs,
    required AudioFilterSink sink,
    this.applyInterval = const Duration(milliseconds: 60),
  }) : _prefs = prefs,
       _sink = sink,
       super(_read(prefs)) {
    _lastConfig = EqFilterGraph.build(value.settings);
    // Players created later (and the first one) read this on construction.
    unawaited(_apply(_lastConfig));
  }

  final SharedPreferences _prefs;
  final AudioFilterSink _sink;
  final Duration applyInterval;

  Timer? _applyTimer;
  Timer? _saveTimer;
  EqEngineConfig _lastConfig = EqEngineConfig.off;

  EqSettings get settings => value.settings;

  static EqState _read(SharedPreferences prefs) {
    final raw = prefs.getString(PrefsKeys.eq);
    var settings = const EqSettings();
    if (raw != null) {
      try {
        settings = EqSettings.fromJson(_decode(raw));
      } on Object {
        settings = const EqSettings();
      }
    }
    return EqState(
      settings: settings,
      custom: decodeCustomPresets(prefs.getString(PrefsKeys.eqPresets)),
    );
  }

  static Object? _decode(String raw) => jsonDecode(raw);

  /// Switching the equalizer on switches the sound effect off.
  void setEnabled(bool enabled) => _edit(
    settings.copyWith(
      enabled: enabled,
      effectEnabled: enabled ? false : settings.effectEnabled,
    ),
    immediate: true,
  );

  /// Switches the sound effect on or off, remembering which one it is. Turning
  /// it on switches the equalizer off.
  void setEffectEnabled(bool enabled) => _edit(
    settings.copyWith(
      effectEnabled: enabled,
      effectId: settings.effectId ?? SoundEffects.all.first.id,
      enabled: enabled ? false : settings.enabled,
    ),
    immediate: true,
  );

  /// Picks a sound effect and switches it on (and the equalizer off).
  void selectEffect(String id) => _edit(
    settings.copyWith(effectEnabled: true, effectId: id, enabled: false),
    immediate: true,
  );

  /// The preamp is not part of a preset, so it keeps the preset selected.
  void setPreamp(double db) => _edit(
    settings.copyWith(
      enabled: true,
      effectEnabled: false,
      preamp: clampPreamp(db),
    ),
  );

  void setBand(int band, double db) {
    final gains = [...settings.gains];
    gains[band] = clampGain(db);
    _edit(
      settings.copyWith(
        enabled: true,
        effectEnabled: false,
        gains: gains,
        presetId: null,
      ),
    );
  }

  /// Applies [preset] and switches the equalizer on.
  void applyPreset(EqPreset preset) => _edit(
    settings.copyWith(
      enabled: true,
      effectEnabled: false,
      gains: List.of(preset.gains),
      presetId: preset.id,
    ),
    immediate: true,
  );

  void reset() => _edit(
    settings.copyWith(
      preamp: 0,
      gains: List.of(EqPresets.flat.gains),
      presetId: EqPresets.flat.id,
    ),
    immediate: true,
  );

  /// Stores the current curve as a named preset and selects it.
  EqPreset saveCustom(String name) {
    final trimmed = name.trim();
    final preset = EqPreset(
      id: 'custom.${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed.isEmpty ? '自定义 ${value.custom.length + 1}' : trimmed,
      gains: List.of(settings.gains),
      builtIn: false,
    );
    final custom = [...value.custom, preset];
    value = value.copyWith(
      custom: custom,
      settings: settings.copyWith(presetId: preset.id),
    );
    unawaited(
      _prefs.setString(PrefsKeys.eqPresets, encodeCustomPresets(custom)),
    );
    _scheduleSave();
    return preset;
  }

  void deleteCustom(String id) {
    final custom = [
      for (final p in value.custom)
        if (p.id != id) p,
    ];
    final selected = settings.presetId == id;
    value = value.copyWith(
      custom: custom,
      settings: selected ? settings.copyWith(presetId: null) : settings,
    );
    unawaited(
      _prefs.setString(PrefsKeys.eqPresets, encodeCustomPresets(custom)),
    );
    if (selected) _scheduleSave();
  }

  void _edit(EqSettings next, {bool immediate = false}) {
    if (next == settings) return;
    value = value.copyWith(settings: next);
    _scheduleSave();
    if (immediate) {
      _applyTimer?.cancel();
      _applyTimer = null;
      unawaited(_flush());
    } else {
      _applyTimer ??= Timer(applyInterval, () {
        _applyTimer = null;
        unawaited(_flush());
      });
    }
  }

  Future<void> _flush() async {
    final config = EqFilterGraph.build(settings);
    if (config == _lastConfig) return;
    _lastConfig = config;
    await _apply(config);
  }

  Future<void> _apply(EqEngineConfig config) async {
    try {
      await _sink(config);
    } on Object catch (error) {
      debugPrint('equalizer filter failed: $error');
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  void _save() {
    _saveTimer = null;
    unawaited(_prefs.setString(PrefsKeys.eq, jsonEncode(settings.toJson())));
  }

  /// Persists anything still pending; call before the process goes away.
  void flush() {
    if (_saveTimer != null) {
      _saveTimer!.cancel();
      _save();
    }
  }

  @override
  void dispose() {
    _applyTimer?.cancel();
    flush();
    super.dispose();
  }
}
