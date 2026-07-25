import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../data/remote/remote_social_repository.dart';
import '../../domain/entities/social.dart';
import '../../domain/repositories/social_repository.dart';
import 'v2_providers.dart';

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => RemoteSocialRepository(ref.watch(v2ApiClientProvider)),
);

/// Whether the current player has an account (social features are account-only).
final _isSignedInProvider = Provider<bool>(
  (ref) =>
      ref.watch(sessionControllerProvider).asData?.value.isSignedIn ?? false,
);

/// Discoverable players. Empty for guests (social requires an account); the
/// screen shows a sign-in prompt in that case rather than surfacing an error.
final playersDirectoryProvider =
    FutureProvider.autoDispose<SocialDirectory>((ref) async {
      if (!ref.watch(_isSignedInProvider)) return const SocialDirectory();
      return ref.watch(socialRepositoryProvider).listPlayers(limit: 40);
    });

/// Pending room invitations addressed to me. Empty for guests.
final incomingInvitationsProvider =
    FutureProvider.autoDispose<List<RoomInvitation>>((ref) async {
      if (!ref.watch(_isSignedInProvider)) return const [];
      return ref.watch(socialRepositoryProvider).incomingInvitations();
    });
