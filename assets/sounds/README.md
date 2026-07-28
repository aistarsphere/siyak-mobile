# Siyaq sound effects

## ⚠️ TEMPORARY DEVELOPMENT ASSETS — REPLACE BEFORE RELEASE

Every file in this directory is prefixed `dev_` and was **synthesized by
`tool/gen_dev_sounds.py`** (Python stdlib sine/square tones). They exist so the
sound *architecture* can be built, wired and QA'd before final audio is
approved. They are deliberately artificial-sounding so nobody mistakes them for
production audio.

- **Provenance / license:** self-generated waveforms, no third-party material,
  no license obligations.
- **Replacing them:** drop in final assets (same names without the `dev_`
  prefix or new names) and update only the `SoundSpec` table in
  `lib/core/sound/sound_service.dart` — asset path and `length` per event.
  Nothing else in the app references files directly.
- **Format requirements:** mono 16-bit 44.1 kHz WAV. iOS cannot decode OGG, so
  OGG is not an option. Keep pooled clips under ~1.5 s (Android SoundPool
  silently drops clips over ~1 MB decoded); `victory`/`defeat` may run longer
  because they play on the standard player, not the pool.

## Event → file → duration

`SoundSpec.length` in `sound_service.dart` must match this table — a unit test
asserts every event's file exists.

| Event            | File                     | Length |
|------------------|--------------------------|--------|
| primaryTap       | dev_primary_tap.wav      | 40 ms  |
| validGuess       | dev_valid_guess.wav      | 220 ms |
| bestImproved     | dev_best_improved.wav    | 330 ms |
| veryClose        | dev_very_close.wav       | 400 ms |
| invalidWord      | dev_invalid_word.wav     | 150 ms |
| duplicateGuess   | dev_duplicate_guess.wav  | 220 ms |
| hintReveal       | dev_hint_reveal.wav      | 260 ms |
| roomJoined       | dev_room_joined.wav      | 300 ms |
| countdown        | dev_countdown.wav        | 120 ms |
| victory          | dev_victory.wav          | 900 ms |
| defeat           | dev_defeat.wav           | 700 ms |

## Silent-mode behavior (by design)

- **iOS** — the audio session is `.ambient` with `mixWithOthers`: the hardware
  **mute switch silences all game SFX**, and the app never interrupts the
  user's music/podcasts. This is the HIG-correct category for game sound
  effects. *QA note: a device with the mute switch on will be silent — that is
  not a bug.*
- **Android** — SFX play on the media stream (usage `game`, no audio focus).
  Ringer **silent/vibrate does not mute media** on Android; only media volume
  at zero (or OEM DND media suppression) silences it. This asymmetry with iOS
  is expected. The in-app Sound toggle is the reliable off switch on both
  platforms.
