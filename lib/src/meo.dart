import 'dart:typed_data';

import 'package:dort/dort.dart';
import 'package:espeak/espeak.dart';

import 'npz_reader.dart';
import 'text_cleaner.dart';
import 'wav.dart';

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

/// Text-to-speech engine.
///
/// ```dart
/// final meo = Meo.init('model.onnx', voicesPath: 'voices.npz');
/// final pcm = meo.speak('Hello world');
/// meo.save('Hello world', 'output.wav');
/// meo.dispose();
/// ```
class Meo {
  final Session _session;
  final Espeak _espeak;
  final TextCleaner _cleaner;
  final Map<String, Float32List> _voices;
  String _currentVoice;

  Meo._(
    this._session,
    this._espeak,
    this._cleaner,
    this._voices,
    this._currentVoice,
  );

  /// Initialize the TTS engine.
  ///
  /// [modelPath] path to the KittenTTS ONNX model.
  /// [voicesPath] path to the voices.npz file.
  /// [speaker] voice name: Bella, Jasper, Luna, Bruno, Rosie, Hugo, Kiki, Leo.
  factory Meo.init(
    String modelPath, {
    required String voicesPath,
    String? espeakDataPath,
    String language = 'en-us',
    String speaker = 'Luna',
  }) {
    final session = Session.load(modelPath);

    final espeak = Espeak.init(
      espeakDataPath ?? _defaultEspeakDataPath(),
      voice: language,
    );

    // Load full voice embeddings [400, 256] per voice.
    final npz = NpzReader.load(voicesPath);
    final voices = <String, Float32List>{};
    for (final entry in _voiceKeys.entries) {
      final data = npz[entry.value];
      if (data != null) voices[entry.key] = data;
    }

    return Meo._(session, espeak, TextCleaner(), voices, speaker);
  }

  /// Available speaker names.
  List<String> get speakers => _voices.keys.toList();

  /// Set the speaker voice.
  set speaker(String name) {
    if (!_voices.containsKey(name)) {
      throw ArgumentError('Unknown speaker: $name. Available: $speakers');
    }
    _currentVoice = name;
  }

  /// Convert text to audio samples.
  ///
  /// Returns 24kHz mono float32 PCM in range [-1.0, 1.0].
  Float32List speak(String text, {double speed = 1.0}) {
    final chunks = _chunkText(text);
    final allSamples = <double>[];

    for (final chunk in chunks) {
      final wav = _speakChunk(chunk, speed: speed);
      allSamples.addAll(wav);
    }

    final result = Float32List.fromList(allSamples);

    // Normalize for audibility.
    var peak = 0.0;
    for (var i = 0; i < result.length; i++) {
      final abs = result[i].abs();
      if (abs > peak) peak = abs;
    }
    if (peak > 0) {
      for (var i = 0; i < result.length; i++) {
        result[i] = result[i] / peak * 0.9;
      }
    }

    return result;
  }

  Float32List _speakChunk(String text, {double speed = 1.0}) {
    final phonemes = _espeak.phonemize(text);
    final inputIds = _cleaner.encode(phonemes);
    final seqLen = inputIds.length;

    // Select style row based on text length (matching KittenTTS).
    final voiceData = _voices[_currentVoice];
    final style = voiceData != null
        ? _selectStyleRow(voiceData, text.length)
        : Float32List(256);

    final outputs = _session.run([
      Tensor.i64('input_ids', inputIds, [1, seqLen]),
      Tensor('style', style, [1, 256]),
      Tensor('speed', Float32List.fromList([speed]), [1]),
    ]);

    final wav = outputs.first;

    // Trim last 5000 samples (silence/artifacts), matching KittenTTS.
    if (wav.length > 5000) {
      return Float32List.sublistView(wav, 0, wav.length - 5000);
    }
    return wav;
  }

  /// Select a style embedding row based on text length.
  static Float32List _selectStyleRow(Float32List fullVoice, int textLen) {
    const rowSize = 256;
    final numRows = fullVoice.length ~/ rowSize;
    final rowIdx = textLen.clamp(0, numRows - 1);
    return Float32List.sublistView(
      fullVoice,
      rowIdx * rowSize,
      (rowIdx + 1) * rowSize,
    );
  }

  static List<String> _chunkText(String text, {int maxLen = 400}) {
    final sentences = text.split(RegExp(r'[.!?]+'));
    final chunks = <String>[];

    for (var sentence in sentences) {
      sentence = sentence.trim();
      if (sentence.isEmpty) continue;

      if (sentence.length <= maxLen) {
        chunks.add(_ensurePunctuation(sentence));
      } else {
        final words = sentence.split(' ');
        var temp = '';
        for (final word in words) {
          if (temp.length + word.length + 1 <= maxLen) {
            temp = temp.isEmpty ? word : '$temp $word';
          } else {
            if (temp.isNotEmpty) chunks.add(_ensurePunctuation(temp.trim()));
            temp = word;
          }
        }
        if (temp.isNotEmpty) chunks.add(_ensurePunctuation(temp.trim()));
      }
    }

    return chunks;
  }

  static String _ensurePunctuation(String text) {
    text = text.trim();
    if (text.isEmpty) return text;
    if (!'.!?,;:'.contains(text[text.length - 1])) return '$text,';
    return text;
  }

  /// Convert text to a WAV file.
  void save(
    String text,
    String path, {
    double speed = 1.0,
    int sampleRate = 24000,
  }) {
    final pcm = speak(text, speed: speed);
    saveWav(path, pcm, sampleRate: sampleRate);
  }

  /// Set the phonemization language.
  void setLanguage(String name) => _espeak.setVoice(name);

  /// Release all resources.
  void dispose() {
    _session.dispose();
    _espeak.dispose();
  }

  static String _defaultEspeakDataPath() {
    throw StateError(
      'espeakDataPath is required until espeak_data package is available',
    );
  }
}
