import 'package:audioplayers/audioplayers.dart';

/// No-op adapter — for tests and any environment without audio output.
class SilentSoundAdapter implements SoundPlayerAdapter {
  const SilentSoundAdapter();

  @override
  Future<void> load(String asset) async {}

  @override
  Future<void> playPooled(String asset) async {}

  @override
  Future<void> playLong(String asset) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}
}

/// Seam between [SoundService] and the audio plugin.
///
/// The only file in the app that imports `audioplayers`. Tests override the
/// adapter provider with [SilentSoundAdapter] or a recording fake, so no
/// method-channel mocking is ever needed.
abstract class SoundPlayerAdapter {
  /// Decode [asset] into the low-latency pool ahead of time.
  Future<void> load(String asset);

  /// Fire-and-forget playback from the pool (short clips only).
  Future<void> playPooled(String asset);

  /// Playback on a standard player — for clips too long for the pool
  /// (victory/defeat).
  Future<void> playLong(String asset);

  /// Stop everything currently sounding.
  Future<void> stopAll();

  Future<void> dispose();
}

/// Production adapter over `audioplayers`.
///
/// * Android: media stream with `usage: game` and **no audio focus** — a
///   sub-second SFX must never duck the user's music.
/// * iOS: `.ambient` + `mixWithOthers` — the hardware mute switch silences SFX
///   (HIG-correct for game sounds; documented in assets/sounds/README.md).
class AudioplayersAdapter implements SoundPlayerAdapter {
  /// Construction is deliberately side-effect-free: creating an [AudioPlayer]
  /// starts plugin channel traffic, which throws asynchronously in tests and
  /// wastes startup time in production. Everything initializes on first use.
  AudioplayersAdapter();

  static const _poolMax = 3;

  final _pools = <String, AudioPool>{};
  AudioPlayer? _long;
  var _configured = false;
  var _disposed = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    await AudioPlayer.global.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.sonification,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ),
    );
  }

  @override
  Future<void> load(String asset) async {
    if (_disposed || _pools.containsKey(asset)) return;
    await _ensureConfigured();
    _pools[asset] = await AudioPool.createFromAsset(
      path: asset,
      maxPlayers: _poolMax,
    );
  }

  @override
  Future<void> playPooled(String asset) async {
    if (_disposed) return;
    // First play of a lazy asset: load then fire. One late clip beats an
    // await-blocked UI; SoundPool decode is async on Android.
    final pool = _pools[asset];
    if (pool == null) {
      await load(asset);
      await _pools[asset]?.start();
      return;
    }
    await pool.start();
  }

  @override
  Future<void> playLong(String asset) async {
    if (_disposed) return;
    await _ensureConfigured();
    final player = _long ??= AudioPlayer();
    await player.stop();
    await player.play(AssetSource(asset));
  }

  @override
  Future<void> stopAll() async {
    if (_disposed) return;
    await _long?.stop();
    // Pooled clips are sub-1.5s fire-and-forget; AudioPool exposes no stop-all,
    // and by the time a stop mattered the clip is over. The long player is the
    // only one that can meaningfully outlive a lifecycle change.
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _long?.dispose();
    for (final pool in _pools.values) {
      await pool.dispose();
    }
    _pools.clear();
  }
}
