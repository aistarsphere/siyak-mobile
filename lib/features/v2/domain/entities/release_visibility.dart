/// Release/version information for the Profile screen.
///
/// Backed by `GET /api/v1/release-visibility` — the **only** endpoint this
/// feature uses. Activation and visibility are independent on the server: a
/// release can be active and completely hidden, so nothing here infers what the
/// player is allowed to see. The client never asserts its own eligibility and
/// never reads an `/admin/*` route.
///
/// Every failure path resolves to [ReleaseVisibility.hidden] — the same value a
/// deliberately hidden policy produces — so a hidden section leaks nothing about
/// whether the feature exists.
library;

import 'package:flutter/foundation.dart';

/// A field the server may **omit** (switched off by policy) or send as **null**
/// (genuinely absent from a legacy release). Those are different things, and
/// collapsing them into one nullable would lose the distinction the contract is
/// explicit about.
///
/// Neither case renders a row, so a player cannot tell a policy-hidden field
/// from one the backend does not have — but the model keeps the difference so
/// the decoder stays honest and testable.
@immutable
class Gated<T> {
  /// The server did not send this key at all.
  const Gated.absent() : present = false, value = null;

  /// The server sent this key, possibly with a null value.
  const Gated.of(this.value) : present = true;

  /// Whether the key was present in the payload.
  final bool present;

  /// The value, or null when present-but-null (legacy release).
  final T? value;

  /// Present *and* carrying a value — the only case worth rendering.
  bool get hasValue => present && value != null;

  @override
  bool operator ==(Object other) =>
      other is Gated<T> && other.present == present && other.value == value;

  @override
  int get hashCode => Object.hash(present, value);

  @override
  String toString() => present ? 'Gated($value)' : 'Gated.absent()';
}

/// Server-declared audience for the current policy.
///
/// Modelled because the payload carries it, **never rendered**: it is policy
/// metadata, not player-facing information. Unrecognised values decode to
/// [unknown] rather than throwing, so a new server scope cannot break the app.
enum ReleaseVisibilityScope {
  hidden,
  internalTesters,
  allUsers,

  /// Absent, or a value this client build does not know.
  unknown;

  static ReleaseVisibilityScope fromCode(Object? raw) =>
      switch (raw?.toString()) {
        'hidden' => hidden,
        'internal_testers' => internalTesters,
        'all_users' => allUsers,
        _ => unknown,
      };
}

/// The release a **newly created** game would use right now.
@immutable
class ResolvedRelease {
  const ResolvedRelease({
    this.releaseId = const Gated.absent(),
    this.displayName,
    this.datasetVersion = const Gated.absent(),
    this.language,
    this.pack = const Gated.absent(),
    this.status,
    this.sourceCommit = const Gated.absent(),
  });

  /// Gated by `show_release_id`.
  final Gated<String> releaseId;

  /// Not policy-gated, but null on a legacy release that never had one.
  final String? displayName;

  /// Gated by `show_dataset_version`.
  final Gated<String> datasetVersion;

  final String? language;

  /// Gated by `show_pack`.
  final Gated<String> pack;

  final String? status;

  /// Gated by `show_source_commit`, which the server clamps to internal testers
  /// even under `all_users`. If it arrives, the caller is already eligible.
  final Gated<String> sourceCommit;

  /// The player-facing name for this release.
  ///
  /// Documented fallback: `display_name` when present, otherwise `release_id`.
  /// Null when neither is available — the caller renders no row rather than a
  /// placeholder.
  String? get label => displayName ?? releaseId.value;
}

/// The release the caller's most recent resumable game is **pinned** to.
///
/// A game keeps its creation release for life; activating a new release only
/// affects new games. Nothing here implies a migration.
@immutable
class CurrentGameRelease {
  const CurrentGameRelease({
    this.releaseId = const Gated.absent(),
    this.displayName,
    this.pinned = false,
    this.unknownRelease = false,
  });

  final Gated<String> releaseId;
  final String? displayName;

  /// Always true for a real pinned release; absent for a pre-pinning game.
  final bool pinned;

  /// The game predates release pinning, so the server cannot say which release
  /// it used. Render a neutral localized label — never guess from
  /// [ReleaseVisibility.resolvedRelease].
  final bool unknownRelease;

  /// Same fallback chain as [ResolvedRelease.label].
  String? get label => displayName ?? releaseId.value;

  /// A legacy game with no recorded release.
  bool get isUnknownLegacy => unknownRelease || label == null;
}

/// Decoded `GET /release-visibility` response.
@immutable
class ReleaseVisibility {
  const ReleaseVisibility({
    required this.visible,
    this.scope = ReleaseVisibilityScope.unknown,
    this.resolvedRelease,
    this.currentGameRelease,
    this.releaseChangedForNewGames = false,
    this.lastUpdated,
  });

  /// The safe fallback: policy-disabled, scope-hidden, not-a-tester,
  /// unidentified caller, request failure and decode failure are all this value.
  static const hidden = ReleaseVisibility(visible: false);

  final bool visible;
  final ReleaseVisibilityScope scope;

  /// Null when there is no active release. Not a crash, and not something to
  /// fill in locally.
  final ResolvedRelease? resolvedRelease;

  /// Null when there is no resumable game, or when policy omits it. Both mean
  /// "render no current-game row".
  final CurrentGameRelease? currentGameRelease;

  /// True only when the resolved and current-game release ids differ. Server
  /// authoritative — never recomputed here.
  final bool releaseChangedForNewGames;

  final String? lastUpdated;

  /// Whether the section has anything at all to draw. Guards against a visible
  /// response whose every field was gated away, which would otherwise render an
  /// empty section.
  bool get hasAnythingToShow =>
      visible &&
      ((resolvedRelease?.label != null) ||
          (resolvedRelease?.datasetVersion.hasValue ?? false) ||
          (resolvedRelease?.pack.hasValue ?? false) ||
          (resolvedRelease?.releaseId.hasValue ?? false) ||
          (resolvedRelease?.sourceCommit.hasValue ?? false) ||
          currentGameRelease != null);
}
