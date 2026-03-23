import 'dart:typed_data';

import 'package:dort/dort.dart';
import 'package:espeak/espeak.dart';

import '../meo.dart';
import '../speaker.dart';
import '../tts_utils.dart' as tts;
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

/// KittenTTS engine.
///
/// ```dart
/// final meo = MeoKitten(
///   model: 'kitten.onnx',
///   voices: 'voices.npz',
///   espeakData: './espeak-data',
/// );
/// final luna = Speaker(voice: 'Luna');
/// meo.speak('Hello world', speaker: luna);
/// meo.dispose();
/// ```
class MeoKitten implements Meo {
  final Session _session;
  final Espeak _espeak;
  final TextCleaner _cleaner = TextCleaner();
  final Map<String, Float32List> _voices;

  MeoKitten._({
    required Session session,
    required Espeak espeak,
    required Map<String, Float32List> voices,
  }) : _session = session,
       _espeak = espeak,
       _voices = voices;

  factory MeoKitten({
    required String model,
    required String voices,
    required String espeakData,
  }) {
    final session = Session.load(model);
    final espeak = Espeak.init(espeakData, voice: 'en-us');

    final npz = NpzReader.load(voices);
    final loaded = <String, Float32List>{};
    for (final entry in _voiceKeys.entries) {
      final data = npz[entry.value];
      if (data != null) loaded[entry.key] = data;
    }

    return MeoKitten._(session: session, espeak: espeak, voices: loaded);
  }

  @override
  List<String> get voices => _voices.keys.toList()..sort();

  @override
  Future<Float32List> speak(String text, {required Speaker speaker}) async {
    if (!_voices.containsKey(speaker.voice)) {
      throw ArgumentError(
        'Unknown voice: ${speaker.voice}. '
        'Available: ${voices.join(', ')}',
      );
    }

    final chunks = tts.chunkText(text);
    final allSamples = <double>[];

    for (final chunk in chunks) {
      final phonemizer = speaker.phonemizer;
      final phonemes = phonemizer != null
          ? phonemizer.phonemize(chunk)
          : _espeak.phonemize(chunk);
      allSamples.addAll(_infer(phonemes, speaker));
    }

    final result = Float32List.fromList(allSamples);
    tts.normalize(result);
    return result;
  }

  @override
  void dispose() {
    _session.dispose();
    _espeak.dispose();
  }

  Float32List _infer(String phonemes, Speaker speaker) {
    final inputIds = _cleaner.encode(phonemes);
    final seqLen = inputIds.length;
    final style = _selectStyle(speaker.voice, phonemes.length);

    final outputs = _session.run([
      Tensor.i64('input_ids', inputIds, [1, seqLen]),
      Tensor('style', style, [1, 256]),
      Tensor('speed', Float32List.fromList([speaker.speed]), [1]),
    ]);

    final wav = outputs.first;
    if (wav.length > 5000) {
      return Float32List.sublistView(wav, 0, wav.length - 5000);
    }
    return wav;
  }

  Float32List _selectStyle(String voice, int inputLen) {
    final voiceData = _voices[voice]!;

    const rowSize = 256;
    final numRows = voiceData.length ~/ rowSize;
    if (numRows == 0) return Float32List(rowSize);
    final rowIdx = inputLen.clamp(0, numRows - 1);
    return Float32List.sublistView(
      voiceData,
      rowIdx * rowSize,
      (rowIdx + 1) * rowSize,
    );
  }
}
