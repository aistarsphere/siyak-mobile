import 'dart:io';

import 'package:context_game/core/design/feedback/siyaq_feedback.dart';
import 'package:context_game/core/sound/sound_player_adapter.dart';
import 'package:context_game/core/sound/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records calls instead of touching any audio plugin.
class RecordingAdapter implements SoundPlayerAdapter {
  final loaded = <String>[];
  final pooled = <String>[];
  final long = <String>[];
  var stops = 0;

  @override
  Future<void> load(String asset) async => loaded.add(asset);

  @override
  Future<void> playPooled(String asset) async => pooled.add(asset);

  @override
  Future<void> playLong(String asset) async => long.add(asset);

  @override
  Future<void> stopAll() async => stops++;

  @override
  Future<void> dispose() async {}
}

void main() {
  late RecordingAdapter adapter;
  late bool enabled;
  late DateTime clock;

  SoundService service() => SoundService(
    adapter: adapter,
    isEnabled: () => enabled,
    now: () => clock,
  );

  setUp(() {
    adapter = RecordingAdapter();
    enabled = true;
    clock = DateTime(2026, 1, 1);
  });

  void tick(Duration d) => clock = clock.add(d);

  group('gating', () {
    test('sound off → the adapter is never touched', () {
      enabled = false;
      final s = service();
      for (final e in SiyaqSoundEvent.values) {
        s.play(e);
      }
      expect(adapter.pooled, isEmpty);
      expect(adapter.long, isEmpty);
    });

    test('flipping the setting applies to the very next play', () {
      final s = service();
      s.play(SiyaqSoundEvent.validGuess);
      expect(adapter.pooled, hasLength(1));

      enabled = false;
      tick(const Duration(seconds: 1));
      s.play(SiyaqSoundEvent.validGuess);
      expect(adapter.pooled, hasLength(1)); // unchanged
    });
  });

  group('debounce', () {
    test('same event inside its minGap plays once', () {
      final s = service();
      s.play(SiyaqSoundEvent.validGuess);
      tick(const Duration(milliseconds: 50));
      s.play(SiyaqSoundEvent.validGuess);
      expect(adapter.pooled, hasLength(1));

      tick(const Duration(milliseconds: 200));
      s.play(SiyaqSoundEvent.validGuess);
      expect(adapter.pooled, hasLength(2));
    });

    test('different events inside the same window both play', () {
      final s = service();
      s.play(SiyaqSoundEvent.primaryTap);
      tick(const Duration(milliseconds: 30));
      s.play(SiyaqSoundEvent.validGuess);
      expect(adapter.pooled, hasLength(2));
    });
  });

  group('celebration priority', () {
    test('victory silences the stage and suppresses lesser sounds', () {
      final s = service();
      s.play(SiyaqSoundEvent.victory);
      expect(adapter.stops, 1, reason: 'no overlapping victory/submit sounds');
      expect(adapter.long, hasLength(1));

      // Inside the victory clip: feedback-tier requests are dropped.
      tick(const Duration(milliseconds: 300));
      s.play(SiyaqSoundEvent.validGuess);
      expect(adapter.pooled, isEmpty);

      // After the clip ends they play again.
      tick(const Duration(milliseconds: 700));
      s.play(SiyaqSoundEvent.validGuess);
      expect(adapter.pooled, hasLength(1));
    });

    test('victory itself is debounced — no double celebration', () {
      final s = service();
      s.play(SiyaqSoundEvent.victory);
      tick(const Duration(milliseconds: 500));
      s.play(SiyaqSoundEvent.victory);
      expect(adapter.long, hasLength(1));
    });
  });

  group('loading', () {
    test('preload decodes exactly the hot-path set', () async {
      final s = service();
      await s.preload();
      final expected = SoundService.specs.values
          .where((spec) => spec.preload)
          .map((spec) => spec.asset)
          .toList();
      expect(adapter.loaded, expected);
      expect(expected, isNotEmpty);
    });
  });

  group('spec table invariants', () {
    test('every event has a spec', () {
      for (final e in SiyaqSoundEvent.values) {
        expect(SoundService.specs[e], isNotNull, reason: e.name);
      }
    });

    test('every spec asset exists on disk', () {
      for (final spec in SoundService.specs.values) {
        expect(
          File('assets/${spec.asset}').existsSync(),
          isTrue,
          reason:
              '${spec.asset} — regenerate with tool/gen_dev_sounds.py '
              'or fix the SoundSpec table',
        );
      }
    });

    test('pooled clips stay under the SoundPool-safe ceiling', () {
      for (final spec in SoundService.specs.values.where((s) => s.pooled)) {
        expect(
          spec.length,
          lessThan(const Duration(milliseconds: 1500)),
          reason: '${spec.asset} is too long for low-latency pooling',
        );
      }
    });

    test('celebrations are the only non-pooled clips', () {
      for (final entry in SoundService.specs.entries) {
        expect(
          entry.value.pooled,
          entry.value.tier < 2,
          reason: entry.key.name,
        );
      }
    });
  });
}
