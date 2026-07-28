import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/feedback/siyaq_feedback.dart';
import '../../features/game/presentation/controllers/app_settings_controller.dart';
import 'sound_player_adapter.dart';

/// Everything the service needs to know about one event's clip.
class SoundSpec {
  const SoundSpec(
    this.asset, {
    required this.length,
    required this.tier,
    this.minGap = const Duration(milliseconds: 150),
    this.preload = false,
    this.pooled = true,
  });

  /// Asset path relative to the Flutter asset bundle root, `AssetSource`-style
  /// (no leading `assets/`).
  final String asset;

  /// Real clip duration — **must match the file** (see assets/sounds/README.md).
  /// This is the interrupt clock: Android's low-latency pool fires no reliable
  /// completion events, so suppression windows are computed from these lengths.
  final Duration length;

  /// 0 = UI tick, 1 = gameplay feedback, 2 = celebration. A tier-2 stops the
  /// long player and suppresses lower tiers for its own length.
  final int tier;

  /// Minimum interval between two plays of the *same* event.
  final Duration minGap;

  /// Decoded into the pool right after startup.
  final bool preload;

  /// False for clips too long for the pool (played on the standard player).
  final bool pooled;
}

/// One table, one policy: every sound in the game routes through here.
///
/// Debounce is per event (a global gate would eat legitimate tap→result
/// sequences); celebration priority is timestamp-based against [SoundSpec.length].
class SoundService {
  SoundService({
    required this._adapter,
    required this._isEnabled,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SoundPlayerAdapter _adapter;
  final bool Function() _isEnabled;
  final DateTime Function() _now;

  final _lastPlayed = <SiyaqSoundEvent, DateTime>{};
  DateTime? _suppressBelowCelebrationUntil;

  /// Event table. Lengths mirror `tool/gen_dev_sounds.py`; swapping in final
  /// audio means editing exactly this map.
  static const specs = <SiyaqSoundEvent, SoundSpec>{
    SiyaqSoundEvent.primaryTap: SoundSpec(
      'sounds/dev_primary_tap.wav',
      length: Duration(milliseconds: 40),
      tier: 0,
      minGap: Duration(milliseconds: 80),
      preload: true,
    ),
    SiyaqSoundEvent.validGuess: SoundSpec(
      'sounds/dev_valid_guess.wav',
      length: Duration(milliseconds: 220),
      tier: 1,
      preload: true,
    ),
    SiyaqSoundEvent.bestImproved: SoundSpec(
      'sounds/dev_best_improved.wav',
      length: Duration(milliseconds: 330),
      tier: 1,
      preload: true,
    ),
    SiyaqSoundEvent.veryClose: SoundSpec(
      'sounds/dev_very_close.wav',
      length: Duration(milliseconds: 400),
      tier: 1,
    ),
    SiyaqSoundEvent.invalidWord: SoundSpec(
      'sounds/dev_invalid_word.wav',
      length: Duration(milliseconds: 150),
      tier: 1,
      preload: true,
    ),
    SiyaqSoundEvent.duplicateGuess: SoundSpec(
      'sounds/dev_duplicate_guess.wav',
      length: Duration(milliseconds: 220),
      tier: 1,
      preload: true,
    ),
    SiyaqSoundEvent.hintReveal: SoundSpec(
      'sounds/dev_hint_reveal.wav',
      length: Duration(milliseconds: 260),
      tier: 1,
    ),
    SiyaqSoundEvent.roomJoined: SoundSpec(
      'sounds/dev_room_joined.wav',
      length: Duration(milliseconds: 300),
      tier: 1,
    ),
    SiyaqSoundEvent.countdown: SoundSpec(
      'sounds/dev_countdown.wav',
      length: Duration(milliseconds: 120),
      tier: 1,
      minGap: Duration(milliseconds: 900),
    ),
    SiyaqSoundEvent.victory: SoundSpec(
      'sounds/dev_victory.wav',
      length: Duration(milliseconds: 900),
      tier: 2,
      minGap: Duration(seconds: 2),
      pooled: false,
    ),
    SiyaqSoundEvent.defeat: SoundSpec(
      'sounds/dev_defeat.wav',
      length: Duration(milliseconds: 700),
      tier: 2,
      minGap: Duration(seconds: 2),
      pooled: false,
    ),
  };

  /// Decode the hot-path clips ahead of the first guess. Call once after the
  /// first frame; failures are non-fatal (a game without sound still plays).
  Future<void> preload() async {
    for (final spec in specs.values) {
      if (!spec.preload) continue;
      try {
        await _adapter.load(spec.asset);
      } catch (_) {
        // Missing/undecodable asset must never take the app down.
      }
    }
  }

  /// Fire-and-forget. All gating lives here so every entry point — DS widgets
  /// via the feedback scope, controllers via [FeedbackService] — shares one
  /// debounce and one priority policy.
  void play(SiyaqSoundEvent event) {
    if (!_isEnabled()) return;
    final spec = specs[event]!;
    final now = _now();

    final last = _lastPlayed[event];
    if (last != null && now.difference(last) < spec.minGap) return;

    final suppressed = _suppressBelowCelebrationUntil;
    if (spec.tier < 2 && suppressed != null && now.isBefore(suppressed)) {
      return; // a celebration owns the speaker right now
    }

    _lastPlayed[event] = now;
    if (spec.tier == 2) {
      _suppressBelowCelebrationUntil = now.add(spec.length);
      // No overlapping victory/defeat: silence whatever else is sounding.
      _adapter.stopAll();
    }

    final fire = spec.pooled
        ? _adapter.playPooled(spec.asset)
        : _adapter.playLong(spec.asset);
    // Fire-and-forget; playback errors are non-fatal by design.
    fire.catchError((_) {});
  }

  /// App went to background: kill anything still sounding.
  Future<void> stopAll() => _adapter.stopAll();

  Future<void> dispose() => _adapter.dispose();
}

/// Overridden in tests with a recording fake.
final soundPlayerAdapterProvider = Provider<SoundPlayerAdapter>(
  (ref) => AudioplayersAdapter(),
);

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService(
    adapter: ref.watch(soundPlayerAdapterProvider),
    // Live read on every play, so a settings flip applies instantly without
    // rebuilding the service.
    isEnabled: () => ref.read(appSettingsProvider).sound,
  );
  ref.onDispose(service.dispose);
  return service;
});
