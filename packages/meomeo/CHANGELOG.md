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
