import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/v2_capabilities.dart';
import 'v2_providers.dart';

/// Detects V2 availability. On ANY failure it resolves to
/// [V2Capabilities.unavailable] so the app keeps V1 solo gameplay and shows
/// friendly unavailable states — it never throws into the UI.
final capabilitiesProvider = FutureProvider<V2Capabilities>((ref) async {
  try {
    return await ref.watch(capabilitiesRepositoryProvider).detect();
  } catch (_) {
    return V2Capabilities.unavailable;
  }
});
