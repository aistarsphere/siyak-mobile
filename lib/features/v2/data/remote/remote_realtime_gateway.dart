import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/entities/room_event.dart';
import '../../domain/repositories/v2_repositories.dart';
import 'v2_mappers.dart';

/// Live realtime gateway over the documented WebSocket:
///   `wss://<origin>/api/context-game/v2/rooms/{room_id}/events?installation_id=<uuid>`
/// (auth is the query param — the header is rejected). The first frame is a
/// `room.snapshot`; subsequent frames are `{event_id,seq,type,...}`. Frames are
/// mapped to domain [RoomEvent]s; ordering/gap/reconnect live in the controller.
class RemoteRealtimeGateway implements RealtimeGateway {
  RemoteRealtimeGateway({required this.socketBase, this.myProfileId});

  /// e.g. `wss://host/api/context-game/v2`
  final String socketBase;
  final String? Function()? myProfileId;

  WebSocketChannel? _channel;
  StreamController<RoomEvent>? _out;
  StreamSubscription? _sub;
  Timer? _keepAlive;

  @override
  Stream<RoomEvent> connect({
    required String roomId,
    required String installationId,
  }) {
    final uri = Uri.parse(
      '$socketBase/rooms/$roomId/events?installation_id=$installationId',
    );
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    final out = StreamController<RoomEvent>();
    _out = out;

    _sub = channel.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          out.add(V2Mappers.roomEvent(json, myProfileId?.call()));
        } catch (_) {
          // Ignore malformed frames; the controller recovers via snapshot.
        }
      },
      onError: out.addError,
      onDone: () => out.close(),
      cancelOnError: false,
    );

    // Application keepalive (server also does protocol ping/pong).
    _keepAlive = Timer.periodic(const Duration(seconds: 25), (_) => sendPing());
    return out.stream;
  }

  @override
  void sendPing() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'ping'}));
    } catch (_) {
      /* socket closing */
    }
  }

  @override
  Future<void> disconnect() async {
    _keepAlive?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    await _out?.close();
    _channel = null;
    _sub = null;
    _out = null;
  }
}
