/// A signed-in **account** (contract §3). The public identity is the stable
/// `SYG-XXXXX` id; Google `sub`, tokens and email are never exposed.
class Account {
  const Account({
    required this.publicPlayerId,
    this.displayName,
    this.avatarUrl,
    this.status = 'active',
    this.linkedProviders = const [],
    this.createdAt,
    this.lastActiveAt,
  });

  /// Stable public player id (`SYG-XXXXX`) — safe to display, immutable.
  final String publicPlayerId;
  final String? displayName;
  final String? avatarUrl;

  /// `active` | `disabled` (server-set).
  final String status;

  /// e.g. `['google']`.
  final List<String> linkedProviders;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  bool get isActive => status == 'active';

  /// Name to render, falling back to the public id when unnamed.
  String get effectiveName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!
          : publicPlayerId;

  Account copyWith({String? displayName, String? avatarUrl, String? status}) =>
      Account(
        publicPlayerId: publicPlayerId,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        status: status ?? this.status,
        linkedProviders: linkedProviders,
        createdAt: createdAt,
        lastActiveAt: lastActiveAt,
      );
}
