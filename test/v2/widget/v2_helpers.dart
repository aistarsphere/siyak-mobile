import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:context_game/features/v2/data/installation_id_store.dart';
import 'package:context_game/features/v2/domain/entities/v2_capabilities.dart';
import 'package:context_game/features/v2/presentation/controllers/v2_providers.dart';

import '../../helpers/fake_repository.dart';
import '../../support/v2_mock/v2_mock_overrides.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemStorage implements FlutterSecureStorage {
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

Future<ProviderContainer> v2Container({
  String lang = 'ar',
  V2Capabilities? caps,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Swap the whole V2 layer to in-memory mocks (no live network).
      capabilitiesRepositoryProvider.overrideWithValue(
        MockCapabilitiesRepository(
          capabilities:
              caps ??
              const V2Capabilities(
                available: true,
                weeklyEnabled: true,
                multiplayerEnabled: true,
                adaptiveHintsEnabled: true,
              ),
        ),
      ),
      profileRepositoryProvider.overrideWithValue(MockProfileRepository()),
      weeklyRepositoryProvider.overrideWithValue(MockWeeklyRepository()),
      roomRepositoryProvider.overrideWithValue(MockRoomRepository()),
      realtimeGatewayProvider.overrideWithValue(MockRealtimeGateway()),
      // V1 modes come from the scripted fake (no live network in tests).
      gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
      installationIdStoreProvider.overrideWithValue(
        InstallationIdStore(storage: MemStorage()),
      ),
    ],
  );
}

Widget hostV2(ProviderContainer container, Widget child, {String lang = 'ar'}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}
