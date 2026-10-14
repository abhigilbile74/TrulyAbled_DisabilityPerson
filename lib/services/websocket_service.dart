
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;

  bool _isClosed = false;

  Stream<dynamic> get stream {
    final channel = _channel;
    if (channel == null) return const Stream<dynamic>.empty();
    return channel.stream;
  }

  Future<void> connect(String url) async {
    await close();

    _isClosed = false;

    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;

    try {
      await channel.ready;
    } catch (_) {
      _isClosed = true;
      await channel.sink.close();
      if (identical(_channel, channel)) {
        _channel = null;
      }
      rethrow;
    }
  }

  void send(String data) {
    final channel = _channel;

    if (channel == null || _isClosed) return;

    try {
      channel.sink.add(data);
    } catch (_) {
      // Ignore sends made after the socket has failed or closed.
    }
  }

  Future<void> close() async {
    final channel = _channel;

    _channel = null;
    _isClosed = true;

    if (channel != null) {
      await channel.sink.close();
    }
  }
}
