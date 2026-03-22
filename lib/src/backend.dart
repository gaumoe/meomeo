import 'dart:typed_data';

/// Abstract TTS backend that handles model-specific phonemization,
/// tokenization, voice loading, and ONNX input shaping.
abstract class TtsBackend {
  /// Phonemize text into a phoneme string.
  String phonemize(String text);

  /// Encode phonemes to token IDs for the ONNX model.
  Float32List encode(String phonemes);

  /// Available speaker names.
  List<String> get speakers;

  /// Select a style embedding for the given voice and input length.
  Float32List selectStyle(String voice, int inputLen);

  /// Shape of the style tensor (e.g. [1, 256] or [1, 1, 256]).
  List<int> get styleShape;

  /// Number of samples to trim from the end of generated audio.
  int get trimSamples;

  /// Maximum input token length (0 = unlimited).
  int get maxTokens;

  /// Release resources.
  void dispose();
}
