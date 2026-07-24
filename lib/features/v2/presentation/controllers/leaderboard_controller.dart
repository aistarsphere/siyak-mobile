import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/leaderboard.dart';
import 'v2_providers.dart';

class LeaderboardState {
  const LeaderboardState({
    this.entries = const [],
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
    this.currentPlacement,
    this.error,
  });

  final List<LeaderboardEntry> entries;
  final int page;
  final bool hasMore;
  final bool loading;
  final int? currentPlacement;
  final Object? error;

  LeaderboardState copyWith({
    List<LeaderboardEntry>? entries,
    int? page,
    bool? hasMore,
    bool? loading,
    int? currentPlacement,
    Object? error,
    bool clearError = false,
  }) => LeaderboardState(
    entries: entries ?? this.entries,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    currentPlacement: currentPlacement ?? this.currentPlacement,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Paginated weekly leaderboard loader. Call [load] once with the weekId.
class LeaderboardController extends Notifier<LeaderboardState> {
  String? _weekId;

  @override
  LeaderboardState build() => const LeaderboardState();

  /// Idempotent first load for a given week.
  Future<void> load(String weekId) async {
    if (_weekId == weekId && state.entries.isNotEmpty) return;
    _weekId = weekId;
    state = const LeaderboardState(loading: true);
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_weekId == null) return;
    if (state.loading && state.entries.isNotEmpty) return;
    if (!state.hasMore && state.entries.isNotEmpty) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await ref
          .read(weeklyRepositoryProvider)
          .leaderboard(
            weekId: _weekId!,
            page: state.entries.isEmpty ? 0 : state.page + 1,
            pageSize: 20,
          );
      state = state.copyWith(
        entries: [...state.entries, ...page.entries],
        page: page.page,
        hasMore: page.hasMore,
        loading: false,
        currentPlacement: page.currentPlacement,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }
}

final leaderboardControllerProvider =
    NotifierProvider<LeaderboardController, LeaderboardState>(
      LeaderboardController.new,
    );
