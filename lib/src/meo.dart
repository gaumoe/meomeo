import 'dart:typed_data';

import 'package:dort/dort.dart';

import 'backend.dart';
import 'kitten_backend.dart';
import 'wav.dart';

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
  final TtsBackend _backend;
  String _currentVoice;

  Meo._(this._session, this._backend, this._currentVoice);

  /// Initialize with a KittenTTS model.
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
    final backend = KittenBackend.load(
      voicesPath: voicesPath,
      espeakDataPath: espeakDataPath ?? _requireEspeakData(),
      language: language,
    );
    return Meo._(session, backend, speaker);
  }

  /// Initialize with a custom backend.
  ///
  /// [modelPath] path to the ONNX model.
  /// [backend] the TTS backend to use.
  /// [speaker] initial voice name.
  factory Meo.withBackend(
    String modelPath, {
    required TtsBackend backend,
    String? speaker,
  }) {
    final session = Session.load(modelPath);
    final voice = speaker ?? backend.speakers.first;
    return Meo._(session, backend, voice);
  }

  /// Available speaker names.
  List<String> get speakers => _backend.speakers;

  /// Set the speaker voice.
  set speaker(String name) {
    if (!_backend.speakers.contains(name)) {
      throw ArgumentError(
        'Unknown speaker: $name. Available: ${_backend.speakers}',
      );
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
    final phonemes = _backend.phonemize(text);
    var inputIds = _backend.encode(phonemes);

    // Enforce max token limit if backend requires it.
    final maxTokens = _backend.maxTokens;
    if (maxTokens > 0 && inputIds.length > maxTokens) {
      inputIds = Float32List.sublistView(inputIds, 0, maxTokens);
    }

    final seqLen = inputIds.length;
    final style = _backend.selectStyle(_currentVoice, text.length);
    final styleShape = _backend.styleShape;

    final outputs = _session.run([
      Tensor.i64('input_ids', inputIds, [1, seqLen]),
      Tensor('style', style, styleShape),
      Tensor('speed', Float32List.fromList([speed]), [1]),
    ]);

    final wav = outputs.first;

    final trim = _backend.trimSamples;
    if (trim > 0 && wav.length > trim) {
      return Float32List.sublistView(wav, 0, wav.length - trim);
    }
    return wav;
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

  /// Set the phonemization language (if backend supports it).
  void setLanguage(String name) {
    // Backend handles language internally.
  }

  /// Release all resources.
  void dispose() {
    _session.dispose();
    _backend.dispose();
  }

  static String _requireEspeakData() {
    throw StateError(
      'espeakDataPath is required until espeak_data package is available',
    );
  }
}
