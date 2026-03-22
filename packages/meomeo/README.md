# meomeo

[![pub package](https://img.shields.io/pub/v/meomeo.svg)](https://pub.dev/packages/meomeo)

Text to speech for Dart. Text in, audio out.

Uses [espeak-ng](https://github.com/espeak-ng/espeak-ng) for phonemization and [ONNX Runtime](https://onnxruntime.ai/) for neural inference. Compatible with [KittenTTS](https://github.com/KittenML/KittenTTS) models.

## Requirements

- **Rust toolchain** (`rustup`) — [dort](https://pub.dev/packages/dort) compiles ONNX Runtime automatically
- **C compiler** (Xcode on macOS, gcc on Linux) — [espeak](https://pub.dev/packages/espeak) compiles espeak-ng automatically

Both compile once via Dart Native Assets on first `dart run`.

## Setup

### 1. Add dependencies

```yaml
dependencies:
  meomeo: ^0.1.0

dev_dependencies:
  espeak: ^0.1.0  # needed to compile phoneme data
```

### 2. Download a KittenTTS model

**Nano** (15M params, fast — recommended to start):
```bash
curl -L -o model.onnx https://huggingface.co/KittenML/kitten-tts-nano-0.8/resolve/main/kitten_tts_nano_v0_8.onnx
curl -L -o voices.npz https://huggingface.co/KittenML/kitten-tts-nano-0.8/resolve/main/voices.npz
```

**Mini** (80M params, better quality):
```bash
curl -L -o model.onnx https://huggingface.co/KittenML/kitten-tts-mini-0.8/resolve/main/kitten_tts_mini_v0_8.onnx
curl -L -o voices.npz https://huggingface.co/KittenML/kitten-tts-mini-0.8/resolve/main/voices.npz
```

### 3. Compile espeak phoneme data

```bash
dart run espeak:compile_data --all --exclude=fo --output ./espeak-data
```

This downloads espeak-ng source automatically and compiles phoneme data for 120 languages. `fo` (Faroese) is excluded because it's 5.4MB alone — add it back with `--all` if needed.

The compiled data is platform-independent. Only needs to run once.

## Usage

```dart
import 'package:meomeo/meomeo.dart';

final meo = Meo.init(
  'model.onnx',
  voicesPath: 'voices.npz',
  espeakDataPath: './espeak-data',
);

// Text to audio (Float32List, 24kHz mono PCM)
final pcm = meo.speak('Hello world');

// Text to WAV file (16-bit PCM, 24kHz, mono)
meo.save('Hello world', 'output.wav');

// Switch voice
meo.speaker = 'Bruno';

// Speed control
final fast = meo.speak('Hello', speed: 1.5);

// Cleanup
meo.dispose();
```

## Voices

Bella, Jasper, Luna, Bruno, Rosie, Hugo, Kiki, Leo
