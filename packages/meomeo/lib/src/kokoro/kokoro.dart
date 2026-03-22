import 'dart:io';
import 'dart:typed_data';

import 'package:dort/dort.dart';
import 'package:espeak/espeak.dart';

import '../meo.dart';
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
class MeoKokoro implements Meo {
  final Session _session;
  final Espeak _espeak;
  final Map<String, Float32List> _voices;
  final bool _british;

  MeoKokoro._({
    required Session session,
    required Espeak espeak,
    required Map<String, Float32List> voices,
    required bool british,
  }) : _session = session,
       _espeak = espeak,
       _voices = voices,
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
      british: language.contains('gb'),
    );
  }

  @override
  List<String> get voices => _voices.keys.toList()..sort();

  @override
  Float32List speak(String text, {required Speaker speaker}) {
    final chunks = tts.chunkText(text);
    final allSamples = <double>[];

    for (final chunk in chunks) {
      final phonemizer = speaker.phonemizer;
      final phonemes = phonemizer != null
          ? phonemizer.phonemize(chunk)
          : _phonemize(chunk);
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

  String _phonemize(String text) {
    var result = _espeak.phonemize(text);
    for (final (from, to) in data.espeakRemap) {
      result = result.replaceAll(from, to);
    }
    result = result.replaceAll('\u0361', '');
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
}
