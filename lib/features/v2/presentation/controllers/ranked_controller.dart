import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/remote_ranked_repository.dart';
import '../../domain/entities/ranked.dart';
import '../../domain/repositories/ranked_repository.dart';
import 'v2_providers.dart';

final rankedRepositoryProvider = Provider<RankedRepository>(
  (ref) => RemoteRankedRepository(ref.watch(v2ApiClientProvider)),
);

/// Available coin tiers (open endpoint; safe for guests to browse).
final rankedTiersProvider = FutureProvider.autoDispose<List<RankedTier>>(
  (ref) => ref.watch(rankedRepositoryProvider).getTiers(),
);

/// The player's ranked standing. Null when unavailable (no profile / transient).
final rankedStatsProvider = FutureProvider.autoDispose<RankedStats?>((ref) async {
  try {
    return await ref.watch(rankedRepositoryProvider).getStats();
  } catch (_) {
    return null;
  }
});
