import 'dart:typed_data';

/// Split text into sentence-sized chunks.
List<String> chunkText(String text, {int maxLen = 400}) {
  final sentences = text.split(RegExp(r'[.!?]+'));
  final chunks = <String>[];
  for (var sentence in sentences) {
    sentence = sentence.trim();
    if (sentence.isEmpty) continue;
    if (sentence.length <= maxLen) {
      chunks.add(ensurePunctuation(sentence));
    } else {
      final words = sentence.split(' ');
      var temp = '';
      for (final word in words) {
        if (temp.length + word.length + 1 <= maxLen) {
          temp = temp.isEmpty ? word : '$temp $word';
        } else {
          if (temp.isNotEmpty) chunks.add(ensurePunctuation(temp.trim()));
          temp = word;
        }
      }
      if (temp.isNotEmpty) chunks.add(ensurePunctuation(temp.trim()));
    }
  }
  return chunks;
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
