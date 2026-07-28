import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/feedback/siyaq_feedback.dart';
import '../../features/game/presentation/controllers/app_settings_controller.dart';
import 'sound_service.dart';

/// Controller-facing feedback facade — sound and haptics behind one gate.
///
/// Riverpod controllers have no BuildContext, so they can't read
/// [SiyaqFeedbackScope]; they use this instead. Both paths funnel into the same
/// [SoundService], so debounce and celebration priority are enforced once.
class FeedbackService {
  FeedbackService(this._ref);

  final Ref _ref;

  /// Play a sound event. Setting gate lives inside [SoundService].
  void play(SiyaqSoundEvent event) =>
      _ref.read(soundServiceProvider).play(event);

  /// Run a haptic if the player has haptics on. Direct replacement for the
  /// `_haptic()` helper each controller used to carry.
  void haptic(Future<void> Function() fn) {
    if (_ref.read(appSettingsProvider).haptics) fn();
  }

  /// The paired sound+haptic response to a scored guess — one call site per
  /// game mode instead of each screen re-deriving the mapping.
  ///
  /// ## Haptic ladder
  ///
  /// Three steps, so intensity actually carries meaning:
  ///
  /// | Event                          | Haptic          |
  /// |--------------------------------|-----------------|
  /// | solved                         | heavy           |
  /// | best improved / very close     | medium          |
  /// | ordinary scored guess          | selection click |
  /// | duplicate                      | light           |
  ///
  /// Beta playtesting drove this: previously most outcomes landed on
  /// `mediumImpact`, so a routine far-off guess felt the same as beating your
  /// record, and rejections used `HapticFeedback.vibrate` — the harshest
  /// pattern Android offers — for the most ordinary mistake in the game.
  void guessResult({
    required bool solved,
    bool duplicate = false,
    double? proximity,
    bool bestImproved = false,
  }) {
    if (solved) {
      play(SiyaqSoundEvent.victory);
      haptic(HapticFeedback.heavyImpact);
      return;
    }
    if (duplicate) {
      play(SiyaqSoundEvent.duplicateGuess);
      haptic(HapticFeedback.lightImpact);
      return;
    }
    if ((proximity ?? 0) >= 75) {
      play(SiyaqSoundEvent.veryClose);
      haptic(HapticFeedback.mediumImpact);
    } else if (bestImproved) {
      play(SiyaqSoundEvent.bestImproved);
      haptic(HapticFeedback.mediumImpact);
    } else {
      // Routine guess: confirm it was scored without competing with the
      // moments above.
      play(SiyaqSoundEvent.validGuess);
      haptic(HapticFeedback.selectionClick);
    }
  }

  /// Word rejected by the vocabulary — worth noticing, not worth flinching at.
  void invalidWord() {
    play(SiyaqSoundEvent.invalidWord);
    haptic(HapticFeedback.mediumImpact);
  }

  /// A submit that failed for a reason other than the word itself (network, or
  /// a server rejection). The composer shakes and shows the reason inline, so
  /// the haptic only needs to say "that didn't land".
  void submitFailed() => haptic(HapticFeedback.lightImpact);

  void hintRevealed() {
    play(SiyaqSoundEvent.hintReveal);
    haptic(HapticFeedback.lightImpact);
  }
}

final feedbackServiceProvider = Provider<FeedbackService>(FeedbackService.new);
