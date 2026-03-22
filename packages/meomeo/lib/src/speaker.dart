import 'phonemizer.dart';

/// Voice configuration for TTS synthesis.
///
/// ```dart
/// final luna = Speaker(voice: 'af_heart');
/// final yuki = Speaker(voice: 'jf_alpha', phonemizer: ja, speed: 0.9);
///
/// final pcm = meo.speak('Hello', speaker: luna);
/// WavWriter().write('out.wav', pcm);
/// ```
class Speaker {
  /// Voice name (must match a loaded voice in the model).
  final String voice;

  /// Custom phonemizer. If null, uses the model's default.
  final Phonemizer? phonemizer;

  /// Speech speed multiplier.
  final double speed;

  const Speaker({
    required this.voice,
    this.phonemizer,
    this.speed = 1.0,
  });
}
