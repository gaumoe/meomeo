import 'dart:typed_data';

/// Controls whether synthesis should include timing metadata.
enum SpeechTiming {
  /// Return audio only.
  none,

  /// Estimate word timing from generated chunk durations and phoneme weight.
  estimatedWords,
}

/// Type of timing mark emitted with synthesized speech.
enum SpeechMarkKind {
  /// A source word or whitespace-delimited token.
  word,
}

/// Timing metadata for a portion of synthesized speech.
class SpeechMark {
  /// Mark type.
  final SpeechMarkKind kind;

  /// Source text covered by this mark.
  final String text;

  /// Inclusive UTF-16 code unit offset in the original source text.
  final int textStart;

  /// Exclusive UTF-16 code unit offset in the original source text.
  final int textEnd;

  /// Inclusive PCM sample offset in [SpeechResult.samples].
  final int sampleStart;

  /// Exclusive PCM sample offset in [SpeechResult.samples].
  final int sampleEnd;

  const SpeechMark({
    required this.kind,
    required this.text,
    required this.textStart,
    required this.textEnd,
    required this.sampleStart,
    required this.sampleEnd,
  });

  /// Start time in seconds for a result with [sampleRate].
  double startSeconds(int sampleRate) => sampleStart / sampleRate;

  /// End time in seconds for a result with [sampleRate].
  double endSeconds(int sampleRate) => sampleEnd / sampleRate;
}

/// Audio and optional timing metadata produced by a TTS engine.
class SpeechResult {
  /// Mono float32 PCM samples in range [-1.0, 1.0].
  final Float32List samples;

  /// Sample rate for [samples].
  final int sampleRate;

  /// Timing marks requested during synthesis.
  final List<SpeechMark> marks;

  SpeechResult({
    required this.samples,
    required this.sampleRate,
    List<SpeechMark> marks = const [],
  }) : marks = List.unmodifiable(marks);

  /// Convert a PCM sample offset into seconds.
  double secondsForSample(int sample) => sample / sampleRate;
}
