/// aMusic's own audio engine as a `just_audio` platform backend.
library;

export 'src/bindings.dart' show AmusicNative, EngineState;
export 'src/platform.dart' show AmusicJustAudio, AmusicJustAudioTestHook;
export 'src/player.dart' show AmusicEq, AmusicPlayer, AmusicReplayGain;
export 'src/tools.dart'
    show AmusicTools, CoverSwatches, ProbedAudio, ProbedContainer;
