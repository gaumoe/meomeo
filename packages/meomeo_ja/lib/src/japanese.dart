import 'package:meomeo/meomeo.dart';
import 'package:dmisaki/misaki.dart';

/// Japanese phonemizer for Kokoro TTS models.
class JapanesePhonemizer implements Phonemizer {
  final JapaneseG2P _g2p;

  JapanesePhonemizer._(this._g2p);

  /// Initialize with a MeCab IpaDic dictionary.
  factory JapanesePhonemizer.init({required String dictPath}) {
    return JapanesePhonemizer._(JapaneseG2P.init(dictPath));
  }

  @override
  String phonemize(String text) => _g2p.convert(text);

  @override
  void dispose() => _g2p.dispose();
}
