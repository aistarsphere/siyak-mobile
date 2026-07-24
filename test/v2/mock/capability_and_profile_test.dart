import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/v2/data/installation_id_store.dart';
import 'package:context_game/features/v2/domain/entities/v2_capabilities.dart';
import 'package:context_game/features/v2/presentation/controllers/capabilities_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/profile_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/v2_providers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/v2_mock/v2_mock_overrides.dart';

class _MemStorage implements FlutterSecureStorage {
  final Map<String, String> _m = {};
  @override
  Future<String?> read({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async => _m[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async => value == null ? _m.remove(key) : _m[key] = value;
  @override
  Future<void> delete({
    required String key,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async => _m.remove(key);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Future<ProviderContainer> container({V2Capabilities? caps}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Force the MOCK profile repo (no live network); capabilities is
      // overridden explicitly for the specific test cases.
      profileRepositoryProvider.overrideWithValue(MockProfileRepository()),
      installationIdStoreProvider.overrideWithValue(
        InstallationIdStore(storage: _MemStorage()),
      ),
      capabilitiesRepositoryProvider.overrideWithValue(
        MockCapabilitiesRepository(capabilities: caps ?? _available),
      ),
    ],
  );
}

const _available = V2Capabilities(
  available: true,
  weeklyEnabled: true,
  multiplayerEnabled: true,
  adaptiveHintsEnabled: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('capability detection', () {
    test('exposes per-feature flags when available', () async {
      final c = await container();
      addTearDown(c.dispose);
      final caps = await c.read(capabilitiesProvider.future);
      expect(caps.available, isTrue);
      expect(caps.weeklyEnabled, isTrue);
      expect(caps.multiplayerEnabled, isTrue);
      expect(caps.adaptiveHintsEnabled, isTrue);
    });

    test('falls back to unavailable (V1 kept) when detection throws', () async {
      final c = await container(caps: V2Capabilities.unavailable);
      addTearDown(c.dispose);
      // Force the repo to throw.
      final c2 = ProviderContainer(
        overrides: [
          capabilitiesRepositoryProvider.overrideWithValue(_ThrowingCaps()),
        ],
      );
      addTearDown(c2.dispose);
      final caps = await c2.read(capabilitiesProvider.future);
      expect(caps.available, isFalse);
      expect(caps.weeklyEnabled, isFalse);
    });
  });

  group('installation profile', () {
    test(
      'registers a profile with a fallback short code, hides the id',
      () async {
        final c = await container();
        addTearDown(c.dispose);
        final profile = await c.read(profileControllerProvider.future);
        expect(profile, isNotNull);
        expect(profile!.installationId, isNotEmpty);
        expect(profile.shortCode, isNotEmpty);
        // Label must not expose the raw installation id.
        expect(profile.label.contains(profile.installationId), isFalse);
        expect(profile.hasDisplayName, isFalse);
      },
    );

    test('updates the display name', () async {
      final c = await container();
      addTearDown(c.dispose);
      await c.read(profileControllerProvider.future);
      await c
          .read(profileControllerProvider.notifier)
          .updateDisplayName('كاظم');
      final updated = c.read(profileControllerProvider).value;
      expect(updated!.displayName, 'كاظم');
      expect(updated.label, 'كاظم');
    });
  });
}

class _ThrowingCaps extends MockCapabilitiesRepository {
  @override
  Future<V2Capabilities> detect() async => throw Exception('offline');
}
