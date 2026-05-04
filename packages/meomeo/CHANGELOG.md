## 0.3.2

- Added `Meo.synthesize()` with `SpeechResult`, sample-rate metadata, and
  optional estimated word timing marks for Piper, Kokoro, and Kitten.
- Raised native dependencies to `espeak ^0.1.3` and `dort ^0.1.1`.

## 0.3.1

- Fixed espeak global state corruption when multiple engines run in the same process.
  Kitten and Kokoro now restore their espeak voice before each `speak()` call.

## 0.3.0

- Added Piper TTS backend.
- **Breaking:** `Meo.speak()` is now async.
- Bug fixes and lint cleanup.

## 0.2.0

- **Breaking:** Meo is now an interface. Use MeoKitten or MeoKokoro.
- **Breaking:** Speaker is pure config (voice, phonemizer, speed). No more Meo reference.
- Added Phonemizer interface for pluggable language support.
- Added MeoKokoro for Kokoro-82M models.
- Added AudioWriter interface for pluggable output formats.
- Monorepo structure with language pack support.

## 0.1.2

- Improved setup documentation.

## 0.1.1

- Fixed doc comment and added setup instructions to README.

## 0.1.0

- Initial release.
