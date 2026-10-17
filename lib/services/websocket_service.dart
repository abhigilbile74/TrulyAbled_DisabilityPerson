import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _closed = true;

  Stream<dynamic> get stream =>
      _channel?.stream ?? const Stream<dynamic>.empty();

  Future<void> connect(String url) async {
    await close();
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    _closed = false;
    try {
      await channel.ready.timeout(const Duration(seconds: 8));
    } catch (_) {
      _closed = true;
      _channel = null;
      await channel.sink.close();
      rethrow;
    }
  }

  void send(String data) {
    final channel = _channel;
    if (channel == null || _closed) return;
    try { channel.sink.add(data); } catch (_) {}
  }

  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    _closed = true;
    if (channel != null) {
      try { await channel.sink.close(); } catch (_) {}
    }
  }
}
