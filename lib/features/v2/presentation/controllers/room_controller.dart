import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/gameplay_language.dart';
import '../../domain/entities/hint_mode.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/v2_repositories.dart';
import 'v2_providers.dart';

/// Room create/join lifecycle (the REST side). Once a [Room] exists, the
/// realtime connection is driven by RealtimeRoomController.
class RoomLifecycleState {
  const RoomLifecycleState({this.room, this.busy = false, this.error});

  final Room? room;
  final bool busy;
  final Object? error;

  RoomLifecycleState copyWith({
    Room? room,
    bool? busy,
    Object? error,
    bool clearError = false,
  }) => RoomLifecycleState(
    room: room ?? this.room,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

class RoomLifecycleController extends Notifier<RoomLifecycleState> {
  @override
  RoomLifecycleState build() => const RoomLifecycleState();

  RoomRepository get _rooms => ref.read(roomRepositoryProvider);

  Future<Room?> create({
    required GameplayLanguage language,
    required String category,
    HintMode hintMode = HintMode.standard,
    int? maxPlayers,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final room = await _rooms.create(
        language: language,
        category: category,
        hintMode: hintMode,
        maxPlayers: maxPlayers,
      );
      state = RoomLifecycleState(room: room);
      return room;
    } catch (e) {
      state = state.copyWith(busy: false, error: e);
      return null;
    }
  }

  Future<Room?> join(String joinCode) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      // Normalize: uppercase, trimmed.
      final room = await _rooms.join(joinCode: joinCode.trim().toUpperCase());
      state = RoomLifecycleState(room: room);
      return room;
    } catch (e) {
      state = state.copyWith(busy: false, error: e);
      return null;
    }
  }

  /// Adopt a room the player has already joined out-of-band (e.g. by accepting a
  /// social invitation, which joins server-side) by pulling its REST snapshot.
  Future<Room?> openById(String roomId) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final room = await _rooms.snapshot(roomId: roomId);
      state = RoomLifecycleState(room: room);
      return room;
    } catch (e) {
      state = state.copyWith(busy: false, error: e);
      return null;
    }
  }

  Future<void> leave() async {
    final room = state.room;
    if (room != null) {
      try {
        await _rooms.leave(roomId: room.roomId);
      } catch (_) {
        /* best-effort */
      }
    }
    state = const RoomLifecycleState();
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final roomLifecycleControllerProvider =
    NotifierProvider<RoomLifecycleController, RoomLifecycleState>(
      RoomLifecycleController.new,
    );

/// Active room id (persisted for resume); null when none.
final activeRoomIdProvider = StateProvider<String?>((ref) => null);
