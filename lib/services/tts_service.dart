import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();

  String _last = "";

  Future<void> speak(String text) async {
    if (text == _last) return;

    _last = text;

    await _tts.stop();
    await _tts.speak(text);
  }

  void dispose() {
    _tts.stop();
  }
}