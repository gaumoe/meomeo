import 'dart:typed_data';

import 'speech_result.dart';
import 'speaker.dart';

/// TTS engine interface.
///
/// Each model type implements this with its own chunking,
/// tokenization, inference, and output processing.
abstract class Meo {
  /// Available voice names.
  List<String> get voices;

  /// Synthesize text to PCM audio.
  ///
  /// Returns mono float32 PCM in range [-1.0, 1.0].
  Future<Float32List> speak(String text, {required Speaker speaker});

  /// Release all resources.
  void dispose();
}

/// TTS engine that can return audio metadata in addition to PCM samples.
abstract interface class MeoSynthesizer implements Meo {
  /// Synthesize text to PCM audio with optional timing metadata.
  Future<SpeechResult> synthesize(
    String text, {
    required Speaker speaker,
    SpeechTiming timing = SpeechTiming.none,
  });
}

/// Convenience synthesis API for any [Meo].
extension MeoSynthesis on Meo {
  /// Synthesize text to PCM audio with optional timing metadata.
  ///
  /// Engines that implement [MeoSynthesizer] return native timing and sample
  /// rate metadata. Older [Meo] implementations fall back to [speak] and a
  /// 24 kHz sample rate with no timing marks.
  Future<SpeechResult> synthesize(
    String text, {
    required Speaker speaker,
    SpeechTiming timing = SpeechTiming.none,
  }) async {
    final meo = this;
    if (meo is MeoSynthesizer) {
      return meo.synthesize(text, speaker: speaker, timing: timing);
    }

    final samples = await speak(text, speaker: speaker);
    return SpeechResult(samples: samples, sampleRate: 24000);
  }
}
