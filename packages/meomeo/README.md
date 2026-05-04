# meomeo

[![pub package](https://img.shields.io/pub/v/meomeo.svg)](https://pub.dev/packages/meomeo)

Text to speech for Dart. Text in, audio out.

Uses [espeak-ng](https://github.com/espeak-ng/espeak-ng) for phonemization and [ONNX Runtime](https://onnxruntime.ai/) for neural inference. Supports multiple model formats: [KittenTTS](https://github.com/KittenML/KittenTTS), [Kokoro](https://huggingface.co/hexgrad/Kokoro-82M), and [Piper](https://github.com/rhasspy/piper).

## Requirements

- **Rust toolchain** (`rustup`) — [dort](https://pub.dev/packages/dort) compiles ONNX Runtime automatically
- **C compiler** (Xcode on macOS, gcc on Linux) — [espeak](https://pub.dev/packages/espeak) compiles espeak-ng automatically

Both compile once via Dart Native Assets on first `dart run`.

## Setup

### 1. Add dependencies

```yaml
dependencies:
  meomeo: ^0.3.2

dev_dependencies:
  espeak: ^0.1.3
```

### 2. Compile espeak phoneme data

```bash
dart run espeak:compile_data --all --exclude=fo --output ./espeak-data
```

This downloads espeak-ng source automatically and compiles phoneme data for 120 languages. `fo` (Faroese) is excluded because it's 5.4MB alone — add it back with `--all` if needed.

The compiled data is platform-independent. Only needs to run once.

### 3. Download a model

See the model-specific sections below for download instructions.

## Engines

meomeo supports three TTS engines. Each has its own class, model format, and voice system.

### KittenTTS

Multi-voice English model. Voices are bundled in a single `.npz` file.

**Download a model:**

Nano (15M params, fast — recommended to start):
```bash
curl -L -o model.onnx https://huggingface.co/KittenML/kitten-tts-nano-0.8/resolve/main/kitten_tts_nano_v0_8.onnx
curl -L -o voices.npz https://huggingface.co/KittenML/kitten-tts-nano-0.8/resolve/main/voices.npz
```

Mini (80M params, better quality):
```bash
curl -L -o model.onnx https://huggingface.co/KittenML/kitten-tts-mini-0.8/resolve/main/kitten_tts_mini_v0_8.onnx
curl -L -o voices.npz https://huggingface.co/KittenML/kitten-tts-mini-0.8/resolve/main/voices.npz
```

**Usage:**

```dart
import 'package:meomeo/meomeo.dart';

final meo = MeoKitten(
  model: 'model.onnx',
  voices: 'voices.npz',
  espeakData: './espeak-data',
);

final luna = Speaker(voice: 'Luna');
final pcm = await meo.speak('Hello world', speaker: luna);

saveWav('output.wav', pcm);
meo.dispose();
```

**Voices:** Bella, Jasper, Luna, Bruno, Rosie, Hugo, Kiki, Leo

### Kokoro

Multi-voice, multi-language model. Voices are individual `.bin` files in a directory.

```dart
final meo = MeoKokoro(
  model: 'kokoro.onnx',
  voices: './voices',
  espeakData: './espeak-data',
);

final speaker = Speaker(voice: 'af_heart');
final pcm = await meo.speak('Hello world', speaker: speaker);

saveWav('output.wav', pcm);
meo.dispose();
```

### Piper

One ONNX model per voice. Supports 30+ languages with hundreds of community voices.

Each model comes with a config file (`model.onnx.json`).

```dart
// Single voice
final meo = MeoPiper(
  model: 'vi_VN-vais1000-medium.onnx',
  espeakData: './espeak-data',
);

// Or load all voices from a directory
final meo = MeoPiper.dir(
  path: './piper-voices',
  espeakData: './espeak-data',
);

final speaker = Speaker(voice: 'vi_VN-vais1000-medium');
final pcm = await meo.speak('Xin chào', speaker: speaker);

saveWav('output.wav', pcm);
meo.dispose();
```

## Speaker

All engines use the `Speaker` class to configure voice and speed:

```dart
final speaker = Speaker(
  voice: 'Luna',       // must match a loaded voice
  speed: 1.2,          // speech speed multiplier (default: 1.0)
  phonemizer: custom,  // optional custom phonemizer (for language packs)
);
```

## Word timing

Use `synthesize()` when you need audio metadata. Existing `speak()` calls still
return PCM audio directly.

```dart
final result = await meo.synthesize(
  'Hello world',
  speaker: luna,
  timing: SpeechTiming.estimatedWords,
);

saveWav('output.wav', result.samples, sampleRate: result.sampleRate);

for (final mark in result.marks) {
  print(
    '${mark.text}: '
    '${mark.startSeconds(result.sampleRate)}s - '
    '${mark.endSeconds(result.sampleRate)}s',
  );
}
```

`SpeechTiming.estimatedWords` preserves source text spans, synthesizes each text
chunk, then distributes the generated sample range across words by phoneme
weight. This is designed for karaoke-style highlighting and subtitle cursors. It
is not forced alignment, so exact phoneme or syllable boundaries are not
guaranteed.

## Language packs

For languages that need specialized phonemization (beyond espeak-ng), use a language pack:

- [meomeo_ja](https://pub.dev/packages/meomeo_ja) — Japanese

```dart
import 'package:meomeo_ja/meomeo_ja.dart';

final ja = JapanesePhonemizer.init(dictPath: '/path/to/ipadic');
final yuki = Speaker(voice: 'jf_alpha', phonemizer: ja);

final pcm = await meo.speak('こんにちは世界', speaker: yuki);
ja.dispose();
```
