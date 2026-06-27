import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  late WebSocketChannel _channel;

  Stream get stream => _channel.stream;

  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
  }

  void send(String data) {
    _channel.sink.add(data);
  }

  void close() {
    _channel.sink.close();
  }
}