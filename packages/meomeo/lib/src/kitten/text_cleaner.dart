import 'dart:typed_data';

/// Maps IPA phoneme characters to integer token IDs for the KittenTTS model.
class TextCleaner {
  static const _pad = r'$';
  static const _punctuation = ';:,.!?¡¿—…\u201c«»\u201d\u201e ';
  static const _letters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  static const _lettersIpa =
      'ɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴ'
      'øɵɸθœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʒʔʡʕʢǀǁǂǃˈˌːˑ'
      "ʼʴʰʱʲʷˠˤ˞↓↑→↗↘\u0027\u0308\u0027ᵻ";

  static final Map<int, int> _charToId = _buildMap();

  static Map<int, int> _buildMap() {
    const symbols = _pad + _punctuation + _letters + _lettersIpa;
    final map = <int, int>{};
    var id = 0;
    for (final rune in symbols.runes) {
      map[rune] = id++;
    }
    return map;
  }

  static final _wordOrPunct = RegExp(
    r'[\p{L}\p{M}\p{N}_]+|[^\s]',
    unicode: true,
  );

  /// Encode a phoneme string to token IDs.
  Float32List encode(String phonemes) {
    // Re-space: split into words and punctuation, rejoin with spaces.
    final respaced = _wordOrPunct
        .allMatches(phonemes)
        .map((m) => m.group(0)!)
        .join(' ');

    final tokens = <int>[0]; // start pad
    for (final rune in respaced.runes) {
      final id = _charToId[rune];
      if (id != null) tokens.add(id);
    }
    tokens.addAll([10, 0]); // end: ellipsis token + pad
    return Float32List.fromList(
      tokens.map((t) => t.toDouble()).toList(),
    );
  }
}
