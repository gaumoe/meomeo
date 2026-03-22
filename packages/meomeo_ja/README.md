# meomeo_ja

[![pub package](https://img.shields.io/pub/v/meomeo_ja.svg)](https://pub.dev/packages/meomeo_ja)

Japanese language pack for [meomeo](https://pub.dev/packages/meomeo) TTS.

## Usage

```dart
import 'package:meomeo/meomeo.dart';
import 'package:meomeo_ja/meomeo_ja.dart';

final meo = MeoKokoro(
  model: 'kokoro.onnx',
  voices: './voices',
  espeakData: './espeak-data',
);

final ja = JapanesePhonemizer.init(dictPath: '/path/to/ipadic');
final yuki = Speaker(voice: 'jf_alpha', phonemizer: ja);

final pcm = meo.speak('こんにちは世界', speaker: yuki);
saveWav('out.wav', pcm);

meo.dispose();
ja.dispose();
```

## Requirements

- [meomeo](https://pub.dev/packages/meomeo) with a Kokoro model
- MeCab IpaDic dictionary (see [mecab](https://pub.dev/packages/mecab))

## License

Apache 2.0
