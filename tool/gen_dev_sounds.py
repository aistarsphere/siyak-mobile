#!/usr/bin/env python3
"""Generate clearly-temporary development sound effects for Siyaq.

Every output is a self-synthesized tone (Python stdlib only — no samples, no
third-party material, no license exposure) written to assets/sounds/ with a
`dev_` prefix so a release build containing them is impossible to miss.

Run from the repo root:  python3 tool/gen_dev_sounds.py

The per-event durations here are the source of truth for the `length` values in
lib/core/sound/sound_service.dart's SoundSpec table — a unit test asserts the
files exist; keep the two in sync when regenerating.
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def _render(segments: list[tuple[float, float, float]]) -> bytes:
    """segments: (frequency Hz, seconds, amplitude 0..1). freq 0 = silence."""
    frames = bytearray()
    for freq, secs, amp in segments:
        n = int(RATE * secs)
        fade = min(int(RATE * 0.005), n // 2)  # 5ms anti-click ramps
        for i in range(n):
            if freq == 0:
                v = 0.0
            else:
                v = math.sin(2 * math.pi * freq * i / RATE)
                # soften with a quieter octave for a less raw sine
                v = 0.8 * v + 0.2 * math.sin(4 * math.pi * freq * i / RATE)
            env = 1.0
            if i < fade:
                env = i / fade
            elif i > n - fade:
                env = (n - i) / fade
            frames += struct.pack("<h", int(v * amp * env * 32767))
    return bytes(frames)


def _square(freq: float, secs: float, amp: float) -> bytes:
    n = int(RATE * secs)
    fade = min(int(RATE * 0.005), n // 2)
    frames = bytearray()
    for i in range(n):
        v = 1.0 if math.sin(2 * math.pi * freq * i / RATE) >= 0 else -1.0
        env = 1.0
        if i < fade:
            env = i / fade
        elif i > n - fade:
            env = (n - i) / fade
        frames += struct.pack("<h", int(v * amp * env * 32767 * 0.5))
    return bytes(frames)


# Event → raw PCM. Durations must match SoundSpec.length in sound_service.dart.
CLIPS: dict[str, bytes] = {
    # 40ms tick
    "primary_tap": _render([(1250, 0.04, 0.35)]),
    # rising two-note, 220ms
    "valid_guess": _render([(660, 0.10, 0.5), (880, 0.12, 0.5)]),
    # brighter three-note rise, 330ms
    "best_improved": _render([(660, 0.10, 0.55), (830, 0.10, 0.55), (1046, 0.13, 0.6)]),
    # urgent high shimmer, 400ms
    "very_close": _render([(1046, 0.08, 0.55), (1318, 0.08, 0.55), (1046, 0.08, 0.5), (1318, 0.16, 0.6)]),
    # low buzz, 150ms
    "invalid_word": _square(140, 0.15, 0.6),
    # flat double-blip, 220ms
    "duplicate_guess": _render([(520, 0.08, 0.5), (0, 0.06, 0.0), (520, 0.08, 0.5)]),
    # soft chime, 260ms
    "hint_reveal": _render([(987, 0.12, 0.45), (1318, 0.14, 0.4)]),
    # welcoming chime, 300ms
    "room_joined": _render([(784, 0.14, 0.5), (1046, 0.16, 0.5)]),
    # short pip, 120ms
    "countdown": _render([(880, 0.12, 0.55)]),
    # 4-note major arpeggio, 900ms
    "victory": _render([(523, 0.18, 0.6), (659, 0.18, 0.6), (784, 0.18, 0.6), (1046, 0.36, 0.65)]),
    # descending minor, 700ms
    "defeat": _render([(659, 0.20, 0.5), (523, 0.20, 0.5), (392, 0.30, 0.5)]),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, pcm in CLIPS.items():
        path = OUT / f"dev_{name}.wav"
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm)
        secs = len(pcm) / 2 / RATE
        print(f"{path.name:26} {secs*1000:6.0f} ms  {path.stat().st_size/1024:6.1f} KB")


if __name__ == "__main__":
    main()
