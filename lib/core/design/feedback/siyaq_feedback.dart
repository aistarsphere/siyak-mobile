import 'package:flutter/widgets.dart';

/// The game's sound vocabulary.
///
/// Lives in the design system so components can *name* a sound without knowing
/// how it is produced — asset mapping, debounce and playback live in the app's
/// sound service, behind [SiyaqFeedback.play].
enum SiyaqSoundEvent {
  /// Primary press feedback.
  primaryTap,

  /// A guess was accepted and scored.
  validGuess,

  /// The accepted guess beat the previous best.
  bestImproved,

  /// The accepted guess landed in the blazing band.
  veryClose,

  /// The word is not in the vocabulary.
  invalidWord,

  /// The word was already played.
  duplicateGuess,

  /// A hint was revealed.
  hintReveal,

  /// Joined a multiplayer room.
  roomJoined,

  /// Turn-timer cue in ranked play.
  countdown,

  /// The word was found.
  victory,

  /// The match ended against the player.
  defeat,
}

/// User-facing feedback preferences plus the sound sink, as one immutable
/// value.
///
/// This is how design-system widgets honour the player's Sound/Haptics
/// settings without depending on the app's state management: the app installs
/// a [SiyaqFeedbackScope] near its root and rebuilds it when settings change.
@immutable
class SiyaqFeedback {
  const SiyaqFeedback({
    this.soundEnabled = false,
    this.hapticsEnabled = true,
    this.play,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;

  /// Fire-and-forget sound sink. Null when no sound backend is installed.
  final void Function(SiyaqSoundEvent event)? play;

  /// Behaviour with no scope installed (tests, gallery, goldens): haptics act
  /// exactly as before the sound system existed, sound is a no-op.
  static const none = SiyaqFeedback();
}

/// Provides [SiyaqFeedback] to the tree.
///
/// Installed once from the app shell (above the Navigator, so pushed routes are
/// covered) and rebuilt whenever the player flips a preference. Widgets read it
/// with [of]; a missing scope degrades to [SiyaqFeedback.none] rather than
/// throwing, so every existing test and gallery page keeps working unwrapped.
class SiyaqFeedbackScope extends InheritedWidget {
  const SiyaqFeedbackScope({
    super.key,
    required this.feedback,
    required super.child,
  });

  final SiyaqFeedback feedback;

  static SiyaqFeedback of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SiyaqFeedbackScope>()
          ?.feedback ??
      SiyaqFeedback.none;

  @override
  bool updateShouldNotify(SiyaqFeedbackScope oldWidget) =>
      feedback.soundEnabled != oldWidget.feedback.soundEnabled ||
      feedback.hapticsEnabled != oldWidget.feedback.hapticsEnabled;
}
