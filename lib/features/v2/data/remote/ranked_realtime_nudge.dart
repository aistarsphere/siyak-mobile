import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Best-effort realtime *nudge* for a ranked match (contract §11 ranked channel:
/// `wss://<origin>/api/context-game/v2/ranked-matches/{match_id}/events?installation_id=<uuid>`).
///
/// It deliberately does NOT parse match state — every incoming frame is a
/// content-agnostic "something changed, refetch" signal, so the authoritative
/// REST snapshot stays the single source of truth. If the socket never connects
/// or later drops, the caller's safety poll keeps driving the match unchanged;
/// nothing about correctness depends on these frames arriving.
class RankedRealtimeNudge {
  RankedRealtimeNudge({required this.socketBase});

  /// e.g. `wss://host/api/context-game/v2`
  final String socketBase;

  /// Emits once per received frame until the socket closes or the subscription
  /// is cancelled. Errors are forwarded so the caller can log/ignore them.
  Stream<void> watch({
    required String matchId,
    required String installationId,
  }) {
    final controller = StreamController<void>();
    final uri = Uri.parse(
      '$socketBase/ranked-matches/$matchId/events?installation_id=$installationId',
    );
    final channel = WebSocketChannel.connect(uri);
    Timer? keepAlive;

    final sub = channel.stream.listen(
      (_) {
        if (!controller.isClosed) controller.add(null);
      },
      onError: (Object e) {
        if (!controller.isClosed) controller.addError(e);
      },
      onDone: () {
        keepAlive?.cancel();
        if (!controller.isClosed) controller.close();
      },
      cancelOnError: false,
    );

    // Application keepalive (server also does protocol ping/pong).
    keepAlive = Timer.periodic(const Duration(seconds: 25), (_) {
      try {
        channel.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {
        /* socket closing */
      }
    });

    controller.onCancel = () async {
      keepAlive?.cancel();
      await sub.cancel();
      await channel.sink.close();
    };
    return controller.stream;
  }
}
