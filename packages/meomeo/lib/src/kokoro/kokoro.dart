import 'dart:io';
import 'dart:typed_data';

import 'package:dort/dort.dart';
import 'package:espeak/espeak.dart';

import '../meo.dart';
import '../speech_result.dart';
import '../speaker.dart';
import '../tts_utils.dart' as tts;
import 'data.dart' as data;

/// Kokoro TTS engine.
///
/// ```dart
/// final meo = MeoKokoro(
///   model: 'kokoro.onnx',
///   voices: './voices',
///   espeakData: './espeak-data',
/// );
/// final luna = Speaker(voice: 'af_heart');
/// meo.speak('Hello world', speaker: luna);
/// meo.dispose();
/// ```
class MeoKokoro implements MeoSynthesizer {
  final Session _session;
  final Espeak _espeak;
  final Map<String, Float32List> _voices;
  final String _language;
  final bool _british;

  MeoKokoro._({
    required Session session,
    required Espeak espeak,
    required Map<String, Float32List> voices,
    required String language,
    required bool british,
  }) : _session = session,
       _espeak = espeak,
       _voices = voices,
       _language = language,
       _british = british;

  factory MeoKokoro({
    required String model,
    required String voices,
    required String espeakData,
    String language = 'en-us',
  }) {
    final session = Session.load(model);
    final espeak = Espeak.init(espeakData, voice: language);

    final dir = Directory(voices);
    final loaded = <String, Float32List>{};
    if (dir.existsSync()) {
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.bin')) continue;
        final name = file.uri.pathSegments.last.replaceAll('.bin', '');
        loaded[name] = Float32List.sublistView(file.readAsBytesSync());
      }
    }

    return MeoKokoro._(
      session: session,
      espeak: espeak,
      voices: loaded,
      language: language,
      british: language.contains('gb'),
    );
  }

  @override
  List<String> get voices => _voices.keys.toList()..sort();

  @override
  Future<Float32List> speak(String text, {required Speaker speaker}) async {
    final result = await synthesize(text, speaker: speaker);
    return result.samples;
  }

  @override
  Future<SpeechResult> synthesize(
    String text, {
    required Speaker speaker,
    SpeechTiming timing = SpeechTiming.none,
  }) async {
    if (!_voices.containsKey(speaker.voice)) {
      throw ArgumentError(
        'Unknown voice: ${speaker.voice}. '
        'Available: ${voices.join(', ')}',
      );
    }

    _espeak.setVoice(_language);

    final chunks = tts.chunkTextWithSpans(text);
    final allSamples = <double>[];
    final marks = <SpeechMark>[];

    for (final chunk in chunks) {
      final phonemizer = speaker.phonemizer;
      String phonemize(String value) =>
          phonemizer != null ? phonemizer.phonemize(value) : _phonemize(value);

      final sampleStart = allSamples.length;
      final phonemes = phonemize(chunk.text);
      allSamples.addAll(_infer(phonemes, speaker));
      final sampleEnd = allSamples.length;

      if (timing == SpeechTiming.estimatedWords) {
        marks.addAll(
          tts.estimateWordMarks(
            chunk: chunk,
            sampleStart: sampleStart,
            sampleEnd: sampleEnd,
            weightForWord: (word) => tts.phonemeWeight(phonemize(word.text)),
          ),
        );
      }
    }

    final result = Float32List.fromList(allSamples);
    tts.normalize(result);
    return SpeechResult(samples: result, sampleRate: 24000, marks: marks);
  }

  @override
  void dispose() {
    _session.dispose();
    _espeak.dispose();
  }

  String _phonemize(String text) {
    var result = _espeak.phonemize(text);
    for (final (from, to) in data.espeakRemap) {
      result = result.replaceAll(from, to);
    }
    result = result.replaceAll('\u0361', '');
    if (!_british) {
      result = result.replaceAll('ɜːɹ', 'ɜɹ');
      result = result.replaceAll('ɜː', 'ɜɹ');
      result = result.replaceAll('ː', '');
    }
    return result;
  }

  Float32List _infer(String phonemes, Speaker speaker) {
    final tokens = <int>[0];
    for (final rune in phonemes.runes) {
      final id = data.vocab[String.fromCharCode(rune)];
      if (id != null) tokens.add(id);
    }
    tokens.add(0);

    final inputIds = Float32List.fromList(
      tokens.take(512).map((t) => t.toDouble()).toList(),
    );

    final seqLen = inputIds.length;
    final style = _selectStyle(speaker.voice, phonemes.length);

    final outputs = _session.run([
      Tensor.i64('input_ids', inputIds, [1, seqLen]),
      Tensor('style', style, [1, 256]),
      Tensor('speed', Float32List.fromList([speaker.speed]), [1]),
    ]);

    return outputs.first;
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
