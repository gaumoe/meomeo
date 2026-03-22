import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dort/dort.dart';
import 'package:espeak/espeak.dart';

import '../meo.dart';
import '../speaker.dart';
import '../tts_utils.dart' as tts;

/// Piper TTS engine.
///
/// Each Piper voice is a separate ONNX model. Create one [MeoPiper] per voice,
/// or per model directory containing multiple voice models.
///
/// ```dart
/// final meo = MeoPiper(
///   model: 'vi_VN-vais1000-medium.onnx',
///   espeakData: './espeak-data',
/// );
/// final speaker = Speaker(voice: 'vi_VN-vais1000-medium');
/// final samples = meo.speak('Xin chào', speaker: speaker);
/// meo.dispose();
/// ```
class MeoPiper implements Meo {
  final Map<String, _PiperVoice> _voices;
  final Espeak _espeak;

  MeoPiper._({
    required Map<String, _PiperVoice> voices,
    required Espeak espeak,
  }) : _voices = voices,
       _espeak = espeak;

  /// Load a single Piper voice from an ONNX model file.
  ///
  /// The config is read from `$model.json` (e.g. `voice.onnx.json`).
  /// [espeakData] is the path to the espeak-ng data directory.
  factory MeoPiper({
    required String model,
    required String espeakData,
  }) {
    final config = _PiperConfig.load('$model.json');
    final session = Session.load(model);
    final espeak = Espeak.init(espeakData, voice: config.espeakVoice);
    final name = _voiceName(model);

    return MeoPiper._(
      voices: {name: _PiperVoice(session: session, config: config)},
      espeak: espeak,
    );
  }

  /// Load all Piper voices from a directory.
  ///
  /// Each `.onnx` file with a matching `.onnx.json` config is loaded as a voice.
  factory MeoPiper.dir({
    required String path,
    required String espeakData,
  }) {
    final dir = Directory(path);
    final voices = <String, _PiperVoice>{};
    String? espeakVoice;

    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.onnx')) continue;
      final configPath = '${file.path}.json';
      if (!File(configPath).existsSync()) continue;

      final config = _PiperConfig.load(configPath);
      final session = Session.load(file.path);
      final name = _voiceName(file.path);
      voices[name] = _PiperVoice(session: session, config: config);
      espeakVoice ??= config.espeakVoice;
    }

    if (voices.isEmpty) {
      throw StateError('No Piper voices found in: $path');
    }

    final espeak = Espeak.init(espeakData, voice: espeakVoice!);
    return MeoPiper._(voices: voices, espeak: espeak);
  }

  @override
  List<String> get voices => _voices.keys.toList()..sort();

  @override
  Future<Float32List> speak(String text, {required Speaker speaker}) async {
    final voice = _voices[speaker.voice];
    if (voice == null) {
      throw ArgumentError(
        'Unknown voice: ${speaker.voice}. '
        'Available: ${voices.join(', ')}',
      );
    }

    // Set espeak voice to match this model's language.
    _espeak.setVoice(voice.config.espeakVoice);

    final chunks = tts.chunkText(text);
    final allSamples = <double>[];

    for (final chunk in chunks) {
      final phonemizer = speaker.phonemizer;
      final phonemes = phonemizer != null
          ? phonemizer.phonemize(chunk)
          : _espeak.phonemize(chunk);
      allSamples.addAll(_infer(phonemes, voice, speaker.speed));
    }

    final result = Float32List.fromList(allSamples);
    tts.normalize(result);
    return result;
  }

  @override
  void dispose() {
    for (final voice in _voices.values) {
      voice.session.dispose();
    }
    _espeak.dispose();
  }

  Float32List _infer(String phonemes, _PiperVoice voice, double speed) {
    final ids = _phonemeToIds(phonemes, voice.config);

    final inputIds = Float32List.fromList(
      ids.map((id) => id.toDouble()).toList(),
    );
    final seqLen = inputIds.length;

    final lengthScale = voice.config.lengthScale / speed;

    final inputs = [
      Tensor.i64('input', inputIds, [1, seqLen]),
      Tensor.i64(
        'input_lengths',
        Float32List.fromList([seqLen.toDouble()]),
        [1],
      ),
      Tensor(
        'scales',
        Float32List.fromList([
          voice.config.noiseScale,
          lengthScale,
          voice.config.noiseW,
        ]),
        [3],
      ),
    ];

    // Multi-speaker models need sid.
    if (voice.config.numSpeakers > 1) {
      inputs.add(
        Tensor.i64(
          'sid',
          Float32List.fromList([voice.config.speakerId.toDouble()]),
          [1],
        ),
      );
    }

    final outputs = voice.session.run(inputs);
    return outputs.first;
  }

  /// Convert IPA phonemes to token IDs using Piper's phoneme_id_map.
  ///
  /// Follows piper-phonemize/src/phoneme_ids.cpp:
  /// BOS(^), then for each phoneme: IDs + PAD(_), then EOS($).
  static List<int> _phonemeToIds(String phonemes, _PiperConfig config) {
    final map = config.phonemeIdMap;
    final ids = <int>[];

    // BOS
    final bos = map['^'];
    if (bos != null) ids.addAll(bos);
    final pad = map['_'] ?? [0];
    ids.addAll(pad);

    // Each IPA codepoint → ID(s) + PAD
    for (final rune in phonemes.runes) {
      final char = String.fromCharCode(rune);
      final mapped = map[char];
      if (mapped != null) {
        ids.addAll(mapped);
        ids.addAll(pad);
      }
    }

    // EOS
    final eos = map['\$'];
    if (eos != null) ids.addAll(eos);

    return ids;
  }

  static String _voiceName(String modelPath) {
    final name = Uri.file(modelPath).pathSegments.last;
    return name.replaceAll('.onnx', '');
  }
}

class _PiperVoice {
  final Session session;
  final _PiperConfig config;

  _PiperVoice({
    required this.session,
    required this.config,
  });
}

class _PiperConfig {
  final int sampleRate;
  final String espeakVoice;
  final double noiseScale;
  final double lengthScale;
  final double noiseW;
  final Map<String, List<int>> phonemeIdMap;
  final int numSpeakers;
  final int speakerId;

  _PiperConfig({
    required this.sampleRate,
    required this.espeakVoice,
    required this.noiseScale,
    required this.lengthScale,
    required this.noiseW,
    required this.phonemeIdMap,
    required this.numSpeakers,
    this.speakerId = 0,
  });

  factory _PiperConfig.load(String path) {
    final json =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

    final audio = json['audio'] as Map<String, dynamic>? ?? {};
    final espeak = json['espeak'] as Map<String, dynamic>? ?? {};
    final inference = json['inference'] as Map<String, dynamic>? ?? {};
    final rawMap = json['phoneme_id_map'] as Map<String, dynamic>? ?? {};

    final phonemeIdMap = <String, List<int>>{};
    for (final entry in rawMap.entries) {
      phonemeIdMap[entry.key] = (entry.value as List).cast<int>();
    }

    return _PiperConfig(
      sampleRate: (audio['sample_rate'] as num?)?.toInt() ?? 22050,
      espeakVoice: (espeak['voice'] as String?) ?? 'en',
      noiseScale: (inference['noise_scale'] as num?)?.toDouble() ?? 0.667,
      lengthScale: (inference['length_scale'] as num?)?.toDouble() ?? 1.0,
      noiseW: (inference['noise_w'] as num?)?.toDouble() ?? 0.8,
      phonemeIdMap: phonemeIdMap,
      numSpeakers: (json['num_speakers'] as num?)?.toInt() ?? 1,
    );
  }
}
