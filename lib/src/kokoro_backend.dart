import 'dart:io';
import 'dart:typed_data';

import 'package:espeak/espeak.dart';

import 'backend.dart';

/// Kokoro phoneme vocabulary (from config.json).
const _vocab = <String, int>{
  ';': 1, ':': 2, ',': 3, '.': 4, '!': 5, '?': 6,
  '\u2014': 9, '\u2026': 10, '"': 11, '(': 12, ')': 13,
  '\u201c': 14, '\u201d': 15, ' ': 16, '\u0303': 17,
  '\u02a3': 18, '\u02a5': 19, '\u02a6': 20, '\u02a8': 21,
  '\u1d5d': 22, '\uab67': 23,
  'A': 24, 'I': 25, 'O': 31, 'Q': 33, 'S': 35, 'T': 36,
  'W': 39, 'Y': 41, '\u1d4a': 42,
  'a': 43, 'b': 44, 'c': 45, 'd': 46, 'e': 47, 'f': 48,
  'h': 50, 'i': 51, 'j': 52, 'k': 53, 'l': 54, 'm': 55,
  'n': 56, 'o': 57, 'p': 58, 'q': 59, 'r': 60, 's': 61,
  't': 62, 'u': 63, 'v': 64, 'w': 65, 'x': 66, 'y': 67,
  'z': 68,
  '\u0251': 69, '\u0250': 70, '\u0252': 71, '\u00e6': 72,
  '\u03b2': 75, '\u0254': 76, '\u0255': 77, '\u00e7': 78,
  '\u0256': 80, '\u00f0': 81, '\u02a4': 82, '\u0259': 83,
  '\u025a': 85, '\u025b': 86, '\u025c': 87, '\u025f': 90,
  '\u0261': 92, '\u0265': 99, '\u0268': 101, '\u026a': 102,
  '\u029d': 103, '\u026f': 110, '\u0270': 111, '\u014b': 112,
  '\u0273': 113, '\u0272': 114, '\u0274': 115, '\u00f8': 116,
  '\u0278': 118, '\u03b8': 119, '\u0153': 120, '\u0279': 123,
  '\u027e': 125, '\u027b': 126, '\u0281': 128, '\u027d': 129,
  '\u0282': 130, '\u0283': 131, '\u0288': 132, '\u02a7': 133,
  '\u028a': 135, '\u028b': 136, '\u028c': 138, '\u0263': 139,
  '\u0264': 140, '\u03c7': 142, '\u028e': 143, '\u0292': 147,
  '\u0294': 148, '\u02c8': 156, '\u02cc': 157, '\u02d0': 158,
  '\u02b0': 162, '\u02b2': 164, '\u2193': 169, '\u2192': 171,
  '\u2197': 172, '\u2198': 173, '\u1d7b': 177,
};

/// Espeak IPA → Kokoro phoneme remapping (from misaki EspeakG2P).
const _espeakRemap = [
  ('a\u0361ɪ', 'I'), ('a\u0361ʊ', 'W'),
  ('d\u0361z', '\u02a3'), ('d\u0361ʒ', '\u02a4'),
  ('e\u0361ɪ', 'A'),
  ('o\u0361ʊ', 'O'), ('ə\u0361ʊ', 'Q'),
  ('t\u0361s', '\u02a6'), ('t\u0361ʃ', '\u02a7'),
  ('ɔ\u0361ɪ', 'Y'),
  // Simple substitutions for non-tie variants.
  ('aɪ', 'I'), ('aʊ', 'W'),
  ('dʒ', '\u02a4'), ('dz', '\u02a3'),
  ('eɪ', 'A'),
  ('oʊ', 'O'), ('əʊ', 'Q'),
  ('ts', '\u02a6'), ('tʃ', '\u02a7'),
  ('ɔɪ', 'Y'),
  // Single char remaps.
  ('ɚ', 'əɹ'), ('r', 'ɹ'), ('ɐ', 'ə'), ('ɬ', 'l'),
  ('ʲ', ''),
];

/// Kokoro TTS backend using espeak for phonemization.
class KokoroBackend extends TtsBackend {
  final Espeak _espeak;
  final Map<String, Float32List> _voices;
  final bool _british;

  KokoroBackend._(this._espeak, this._voices, this._british);

  /// Load a Kokoro backend.
  ///
  /// [voicesDir] directory containing voice .bin files.
  factory KokoroBackend.load({
    required String voicesDir,
    required String espeakDataPath,
    String language = 'en-us',
  }) {
    final espeak = Espeak.init(espeakDataPath, voice: language);
    final british = language.contains('gb');

    final dir = Directory(voicesDir);
    final voices = <String, Float32List>{};
    if (dir.existsSync()) {
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.bin')) continue;
        final name = file.uri.pathSegments.last.replaceAll('.bin', '');
        final bytes = file.readAsBytesSync();
        voices[name] = Float32List.sublistView(bytes);
      }
    }

    return KokoroBackend._(espeak, voices, british);
  }

  @override
  String phonemize(String text) {
    final ipa = _espeak.phonemize(text);
    return _remapToKokoro(ipa);
  }

  String _remapToKokoro(String ipa) {
    var result = ipa;
    for (final (from, to) in _espeakRemap) {
      result = result.replaceAll(from, to);
    }
    // Remove tie characters and hyphens.
    result = result.replaceAll('\u0361', '');
    // British-specific remaps.
    if (_british) {
      result = result.replaceAll('ɛː', 'ɛː');
      result = result.replaceAll('ɪə', 'ɪə');
    } else {
      result = result.replaceAll('ɜːɹ', 'ɜɹ');
      result = result.replaceAll('ɜː', 'ɜɹ');
      result = result.replaceAll('ː', '');
    }
    return result;
  }

  @override
  Float32List encode(String phonemes) {
    final tokens = <int>[0]; // pad start
    for (final rune in phonemes.runes) {
      final char = String.fromCharCode(rune);
      final id = _vocab[char];
      if (id != null) tokens.add(id);
    }
    tokens.add(0); // pad end
    return Float32List.fromList(
      tokens.map((t) => t.toDouble()).toList(),
    );
  }

  @override
  List<String> get speakers => _voices.keys.toList()..sort();

  @override
  Float32List selectStyle(String voice, int inputLen) {
    final voiceData = _voices[voice];
    if (voiceData == null) return Float32List(256);

    const rowSize = 256;
    final numRows = voiceData.length ~/ rowSize;
    final rowIdx = inputLen.clamp(0, numRows - 1);
    return Float32List.sublistView(
      voiceData,
      rowIdx * rowSize,
      (rowIdx + 1) * rowSize,
    );
  }

  @override
  List<int> get styleShape => [1, 256];

  @override
  int get trimSamples => 0;

  @override
  int get maxTokens => 512;

  @override
  void dispose() => _espeak.dispose();
}
