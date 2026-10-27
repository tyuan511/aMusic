import 'package:just_audio/just_audio.dart';

/// Cycling + labelling helpers on just_audio's [LoopMode] so the UI can show
/// three distinct states instead of a boolean.
extension LoopModeX on LoopMode {
  String get label => switch (this) {
    LoopMode.off => '不循环',
    LoopMode.all => '列表循环',
    LoopMode.one => '单曲循环',
  };

  /// all -> one -> off -> all
  LoopMode get next => switch (this) {
    LoopMode.all => LoopMode.one,
    LoopMode.one => LoopMode.off,
    LoopMode.off => LoopMode.all,
  };

  static LoopMode fromName(String? name) => LoopMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => LoopMode.all,
  );
}
