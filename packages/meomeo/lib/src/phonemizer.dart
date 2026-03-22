/// Converts text to phonemes for TTS synthesis.
///
/// Implement this interface in language packs to provide
/// language-specific phonemization.
abstract class Phonemizer {
  /// Convert text to a phoneme string.
  String phonemize(String text);

  /// Release resources.
  void dispose();
}
