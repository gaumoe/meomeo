import 'dart:typed_data';

import 'speech_result.dart';

/// A word/token span in the original source text.
class SourceWord {
  final String text;
  final int start;
  final int end;

  const SourceWord({
    required this.text,
    required this.start,
    required this.end,
  });
}

/// A sentence-sized synthesis chunk with source spans preserved.
class TextChunk {
  final String text;
  final int start;
  final int end;
  final List<SourceWord> words;

  TextChunk({
    required this.text,
    required this.start,
    required this.end,
    required List<SourceWord> words,
  }) : words = List.unmodifiable(words);
}

/// Split text into sentence-sized chunks.
List<String> chunkText(String text, {int maxLen = 400}) {
  return chunkTextWithSpans(
    text,
    maxLen: maxLen,
  ).map((chunk) => chunk.text).toList();
}

/// Split text into sentence-sized chunks while preserving source spans.
List<TextChunk> chunkTextWithSpans(String text, {int maxLen = 400}) {
  final chunks = <String>[];
  final spans = <(int, int)>[];

  var sentenceStart = 0;
  for (var i = 0; i <= text.length; i++) {
    final atEnd = i == text.length;
    final boundary = !atEnd && '.!?'.contains(text[i]);
    if (!atEnd && !boundary) continue;

    final rawStart = sentenceStart;
    final rawEnd = i;
    sentenceStart = i + 1;

    final trimmed = _trimRange(text, rawStart, rawEnd);
    if (trimmed == null) continue;

    final sentence = text.substring(trimmed.$1, trimmed.$2);
    if (sentence.length <= maxLen) {
      chunks.add(ensurePunctuation(sentence));
      spans.add(trimmed);
    } else {
      var chunkStart = -1;
      var chunkEnd = -1;
      var chunkText = '';
      for (final word in _findWords(text, trimmed.$1, trimmed.$2)) {
        final nextText = chunkText.isEmpty
            ? word.text
            : '$chunkText ${word.text}';
        if (nextText.length <= maxLen) {
          chunkStart = chunkStart == -1 ? word.start : chunkStart;
          chunkEnd = word.end;
          chunkText = nextText;
        } else {
          if (chunkText.isNotEmpty) {
            chunks.add(ensurePunctuation(chunkText));
            spans.add((chunkStart, chunkEnd));
          }
          chunkStart = word.start;
          chunkEnd = word.end;
          chunkText = word.text;
        }
      }
      if (chunkText.isNotEmpty) {
        chunks.add(ensurePunctuation(chunkText));
        spans.add((chunkStart, chunkEnd));
      }
    }
  }

  return [
    for (var i = 0; i < chunks.length; i++)
      TextChunk(
        text: chunks[i],
        start: spans[i].$1,
        end: spans[i].$2,
        words: _findWords(text, spans[i].$1, spans[i].$2),
      ),
  ];
}

/// Ensure text ends with punctuation.
String ensurePunctuation(String text) {
  text = text.trim();
  if (text.isEmpty) return text;
  if (!'.!?,;:'.contains(text[text.length - 1])) return '$text,';
  return text;
}

/// Normalize PCM samples to 0.9 peak amplitude.
void normalize(Float32List samples) {
  var peak = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final abs = samples[i].abs();
    if (abs > peak) peak = abs;
  }
  if (peak > 0) {
    for (var i = 0; i < samples.length; i++) {
      samples[i] = samples[i] / peak * 0.9;
    }
  }
}

/// Estimate word timing from generated chunk duration and word weights.
List<SpeechMark> estimateWordMarks({
  required TextChunk chunk,
  required int sampleStart,
  required int sampleEnd,
  required double Function(SourceWord word) weightForWord,
}) {
  if (chunk.words.isEmpty || sampleEnd <= sampleStart) return const [];

  final weights = [
    for (final word in chunk.words) weightForWord(word).clamp(1.0, 1000000.0),
  ];
  final totalWeight = weights.fold<double>(0, (sum, weight) => sum + weight);
  if (totalWeight <= 0) return const [];

  final marks = <SpeechMark>[];
  final sampleCount = sampleEnd - sampleStart;
  var cumulative = 0.0;

  for (var i = 0; i < chunk.words.length; i++) {
    final word = chunk.words[i];
    final start =
        sampleStart + (sampleCount * cumulative / totalWeight).round();
    cumulative += weights[i];
    final end = i == chunk.words.length - 1
        ? sampleEnd
        : sampleStart + (sampleCount * cumulative / totalWeight).round();

    marks.add(
      SpeechMark(
        kind: SpeechMarkKind.word,
        text: word.text,
        textStart: word.start,
        textEnd: word.end,
        sampleStart: start,
        sampleEnd: end,
      ),
    );
  }

  return marks;
}

double phonemeWeight(String phonemes) {
  var weight = 0.0;
  for (final rune in phonemes.runes) {
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) continue;
    if ('.!?,;:'.contains(char)) continue;
    weight += 1;
  }
  return weight <= 0 ? 1 : weight;
}

(int, int)? _trimRange(String text, int start, int end) {
  while (start < end && text[start].trim().isEmpty) {
    start++;
  }
  while (end > start && text[end - 1].trim().isEmpty) {
    end--;
  }
  return start == end ? null : (start, end);
}

List<SourceWord> _findWords(String text, int start, int end) {
  final source = text.substring(start, end);
  return [
    for (final match in RegExp(r'\S+').allMatches(source))
      SourceWord(
        text: match.group(0)!,
        start: start + match.start,
        end: start + match.end,
      ),
  ];
}
