import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/context_game_api.dart';
import '../../data/game_repository_impl.dart';
import '../../data/models/modes_info.dart';
import '../../domain/repositories/game_repository.dart';
import 'app_settings_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl =
      ref.watch(appSettingsProvider.select((s) => s.effectiveBaseUrl));
  return ApiClient(baseUrl: baseUrl);
});

final gameRepositoryProvider = Provider<GameRepository>(
  (ref) => GameRepositoryImpl(ContextGameApi(ref.watch(apiClientProvider))),
);

/// Category catalogue for the currently selected app language. Re-fetches
/// when the language or server changes. Doubles as the splash health check.
final modesProvider = FutureProvider<ModesInfo>((ref) {
  final lang = ref.watch(appSettingsProvider.select((s) => s.lang));
  return ref.watch(gameRepositoryProvider).modes(language: lang);
});
