import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../domain/entities/installation_profile.dart';
import 'v2_providers.dart';

/// Owns the anonymous installation profile.
///
/// First launch: read (or generate + securely store) a UUID v4 installation
/// ID, then register idempotently with V2 and cache the returned public
/// profile. Never surfaces the raw installation ID in the UI.
class ProfileController extends AsyncNotifier<InstallationProfile?> {
  static const _kName = 'siyaq.v2.displayName';
  static const _kShort = 'siyaq.v2.shortCode';

  @override
  Future<InstallationProfile?> build() async {
    final id = await ref.read(installationIdStoreProvider).getOrCreate();
    final sp = ref.read(sharedPreferencesProvider);
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .register(installationId: id, displayName: sp.getString(_kName));
      _cache(profile);
      return profile;
    } catch (_) {
      // Offline: fall back to a cached public profile if we have one, so the
      // app stays usable (V1) without a registered profile.
      final short = sp.getString(_kShort);
      if (short == null) return null;
      return InstallationProfile(
        installationId: id,
        shortCode: short,
        displayName: sp.getString(_kName),
      );
    }
  }

  void _cache(InstallationProfile p) {
    final sp = ref.read(sharedPreferencesProvider);
    sp.setString(_kShort, p.shortCode);
    if (p.displayName != null) sp.setString(_kName, p.displayName!);
  }

  Future<void> updateDisplayName(String name) async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updated = await ref
          .read(profileRepositoryProvider)
          .updateDisplayName(
            installationId: current.installationId,
            displayName: name.trim(),
          );
      _cache(updated);
      return updated;
    });
  }

  /// Whether the first-run display-name setup should be offered.
  bool get needsNameSetup {
    final p = state.value;
    return p != null && !p.hasDisplayName;
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, InstallationProfile?>(
      ProfileController.new,
    );
