import 'dart:typed_data';

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
  /// Returns 24kHz mono float32 PCM in range [-1.0, 1.0].
  Float32List speak(String text, {required Speaker speaker});

  /// Release all resources.
  void dispose();
}
