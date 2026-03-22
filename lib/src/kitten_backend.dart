import 'dart:typed_data';

import 'package:espeak/espeak.dart';

import 'backend.dart';
import 'npz_reader.dart';
import 'text_cleaner.dart';

/// Voice names mapping to NPZ keys.
const _voiceKeys = {
  'Bella': 'expr-voice-2-f',
  'Jasper': 'expr-voice-2-m',
  'Luna': 'expr-voice-4-f',
  'Bruno': 'expr-voice-4-m',
  'Rosie': 'expr-voice-3-f',
  'Hugo': 'expr-voice-3-m',
  'Kiki': 'expr-voice-5-f',
  'Leo': 'expr-voice-5-m',
};

/// KittenTTS backend.
class KittenBackend extends TtsBackend {
  final Espeak _espeak;
  final TextCleaner _cleaner = TextCleaner();
  final Map<String, Float32List> _voices;

  KittenBackend._(this._espeak, this._voices);

  factory KittenBackend.load({
    required String voicesPath,
    required String espeakDataPath,
    String language = 'en-us',
  }) {
    final espeak = Espeak.init(espeakDataPath, voice: language);

    final npz = NpzReader.load(voicesPath);
    final voices = <String, Float32List>{};
    for (final entry in _voiceKeys.entries) {
      final data = npz[entry.value];
      if (data != null) voices[entry.key] = data;
    }

    return KittenBackend._(espeak, voices);
  }

  @override
  String phonemize(String text) => _espeak.phonemize(text);

  @override
  Float32List encode(String phonemes) => _cleaner.encode(phonemes);

  @override
  List<String> get speakers => _voices.keys.toList();

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
  int get trimSamples => 5000;

  @override
  int get maxTokens => 0;

  @override
  void dispose() => _espeak.dispose();
}
