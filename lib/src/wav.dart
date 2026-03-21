import 'dart:io';
import 'dart:typed_data';

/// Write PCM audio samples to a WAV file.
///
/// Samples are expected to be normalized float32 in the range [-1.0, 1.0].
void saveWav(String path, Float32List samples, {int sampleRate = 24000}) {
  final numSamples = samples.length;
  final pcm = Int16List(numSamples);
  for (var i = 0; i < numSamples; i++) {
    pcm[i] = (samples[i].clamp(-1.0, 1.0) * 32767).round();
  }

  final dataSize = numSamples * 2;
  final header = ByteData(44);
  header.setUint32(0, 0x52494646, Endian.big); // RIFF
  header.setUint32(4, 36 + dataSize, Endian.little);
  header.setUint32(8, 0x57415645, Endian.big); // WAVE
  header.setUint32(12, 0x666D7420, Endian.big); // fmt
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  header.setUint32(36, 0x64617461, Endian.big); // data
  header.setUint32(40, dataSize, Endian.little);

  File(path).writeAsBytesSync([
    ...header.buffer.asUint8List(),
    ...pcm.buffer.asUint8List(),
  ]);
}
