import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/ranked.dart';
import '../../domain/repositories/ranked_repository.dart';
import 'ranked_controller.dart';
import 'wallet_controller.dart';

enum MatchmakingPhase { idle, searching, matched, error }

class MatchmakingState {
  const MatchmakingState({
    this.phase = MatchmakingPhase.idle,
    this.ticket,
    this.matchId,
    this.error,
  });

  final MatchmakingPhase phase;
  final MatchmakingTicket? ticket;
  final String? matchId;
  final Object? error;

  bool get isSearching => phase == MatchmakingPhase.searching;

  MatchmakingState copyWith({
    MatchmakingPhase? phase,
    MatchmakingTicket? ticket,
    String? matchId,
    Object? error,
  }) => MatchmakingState(
    phase: phase ?? this.phase,
    ticket: ticket ?? this.ticket,
    matchId: matchId ?? this.matchId,
    error: error,
  );
}

/// Drives the matchmaking flow: join a tier (reserves the entry), poll the
/// ticket until `matched`, then expose the `match_id`. Cancels the hold on
/// leave. Polling stops automatically once terminal.
class MatchmakingController extends Notifier<MatchmakingState> {
  Timer? _poll;

  @override
  MatchmakingState build() {
    ref.onDispose(() => _poll?.cancel());
    return const MatchmakingState();
  }

  RankedRepository get _repo => ref.read(rankedRepositoryProvider);

  Future<void> findMatch({
    required String tierId,
    required String language,
  }) async {
    _poll?.cancel();
    state = const MatchmakingState(phase: MatchmakingPhase.searching);
    try {
      final ticket = await _repo.joinMatchmaking(
        language: language,
        tierId: tierId,
      );
      ref.invalidate(walletControllerProvider); // entry reserved
      _apply(ticket);
    } catch (e) {
      state = MatchmakingState(phase: MatchmakingPhase.error, error: e);
    }
  }

  void _apply(MatchmakingTicket ticket) {
    if (ticket.isMatched) {
      _poll?.cancel();
      state = MatchmakingState(
        phase: MatchmakingPhase.matched,
        ticket: ticket,
        matchId: ticket.matchId,
      );
      return;
    }
    if (ticket.isTerminal) {
      _poll?.cancel();
      state = const MatchmakingState();
      ref.invalidate(walletControllerProvider); // hold released
      return;
    }
    state = MatchmakingState(phase: MatchmakingPhase.searching, ticket: ticket);
    _startPolling(ticket.id);
  }

  void _startPolling(String ticketId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        _apply(await _repo.getTicket(ticketId));
      } catch (e) {
        if (kDebugMode) debugPrint('[Matchmaking] poll error: ${e.runtimeType}');
      }
    });
  }

  Future<void> cancel() async {
    _poll?.cancel();
    final id = state.ticket?.id;
    state = const MatchmakingState();
    if (id != null) {
      try {
        await _repo.cancelTicket(id);
      } catch (_) {}
      ref.invalidate(walletControllerProvider);
    }
  }

  void reset() {
    _poll?.cancel();
    state = const MatchmakingState();
  }
}

final matchmakingControllerProvider =
    NotifierProvider<MatchmakingController, MatchmakingState>(
      MatchmakingController.new,
    );
