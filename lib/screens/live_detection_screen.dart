import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/camera_service.dart';
import '../services/detection_service.dart';
import '../services/websocket_service.dart';

class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({super.key});
  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  final _camera = CameraService();
  final _socket = WebSocketService();
  final _tts = FlutterTts();
  DetectionService? _detection;
  StreamSubscription<dynamic>? _subscription;
  bool _ready = false;
  bool _starting = false;
  String _status = 'Starting camera...';
  List<Map<String, dynamic>> _objects = [];
  String? _lastSpeech;
  DateTime? _lastSpeechAt;

  String get _url {
    if (kIsWeb) return 'ws://127.0.0.1:8000/ws/detect';
    if (defaultTargetPlatform == TargetPlatform.android) {
      // This is for Android emulator. Use laptop LAN IP on a physical phone.
      return 'ws://10.0.2.2:8000/ws/detect';
    }
    return 'ws://127.0.0.1:8000/ws/detect';
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _camera.initialize();
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _socket.connect(_url);
      _subscription = _socket.stream.listen(
        _onMessage,
        onError: (e) {
          if (mounted) setState(() => _status = 'Backend connection error');
          debugPrint('WebSocket error: $e');
        },
        onDone: () {
          if (mounted) setState(() => _status = 'Backend disconnected');
        },
      );
      _detection = DetectionService(cameraService: _camera, socketService: _socket);
      await _detection!.start();
      if (mounted) setState(() { _ready = true; _status = 'Detecting objects'; });
    } catch (e, st) {
      debugPrint('Detection startup failed: $e\n$st');
      if (mounted) {
        setState(() { _ready = false; _status = 'Could not start detection'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start detection: $e')),
        );
      }
    } finally {
      _starting = false;
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      if (data is! Map) return;
      if (data['error'] != null) {
        if (mounted) setState(() => _status = data['error'].toString());
        return;
      }
      final raw = data['objects'];
      final list = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _objects = list;
        _status = list.isEmpty ? 'No object detected' : 'Objects detected';
      });
      if (list.isNotEmpty) {
        final top = list.first;
        final name = (top['name'] ?? 'object').toString();
        final distance = (top['distance_label'] ?? 'distance unknown').toString();
        final text = top['hazard'] == true
            ? '$name detected $distance. Pause and check your surroundings.'
            : '$name detected $distance.';
        _speakThrottled(text);
      }
    } catch (e) {
      debugPrint('Could not parse backend response: $e');
    }
  }

  Future<void> _speakThrottled(String text) async {
    final now = DateTime.now();
    final elapsed = _lastSpeechAt == null ? 999 : now.difference(_lastSpeechAt!).inSeconds;
    if (_lastSpeech == text && elapsed < 5) return;
    _lastSpeech = text;
    _lastSpeechAt = now;
    try { await _tts.stop(); await _tts.speak(text); }
    catch (e) { debugPrint('Speech error: $e'); }
  }

  Future<void> _speakObjects() async {
    if (_objects.isEmpty) {
      _lastSpeech = null;
      await _speakThrottled('No objects detected yet. Move the camera slowly.');
      return;
    }
    _lastSpeech = null;
    final text = _objects.take(3).map((o) =>
      '${o['name'] ?? 'object'}, ${o['distance_label'] ?? 'distance unknown'}'
    ).join('. ');
    await _speakThrottled(text);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _detection?.stop();
    _socket.close();
    _camera.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraReady = _camera.isInitialized;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Object Detection'),
        actions: [
          IconButton(onPressed: _speakObjects, tooltip: 'Speak objects',
            icon: const Icon(Icons.volume_up)),
        ],
      ),
      body: !_ready || !cameraReady
        ? Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _start, child: const Text('Retry')),
            ]),
          ))
        : Stack(children: [
            Positioned.fill(child: CameraPreview(_camera.controller)),
            Positioned(top: 12, left: 12, right: 12, child: Card(
              color: Colors.black87,
              child: Padding(padding: const EdgeInsets.all(12),
                child: Text(_status, style: const TextStyle(color: Colors.white, fontSize: 17))),
            )),
            Positioned(bottom: 12, left: 12, right: 12, child: Card(
              color: Colors.black87,
              child: Padding(padding: const EdgeInsets.all(12),
                child: _objects.isEmpty
                  ? const Text('Waiting for detection results…',
                      style: TextStyle(color: Colors.white))
                  : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: _objects.take(5).map((o) {
                        final confidence = (o['confidence'] as num?)?.toDouble() ?? 0;
                        return Padding(padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${o['name'] ?? 'Object'} • ${(confidence * 100).toStringAsFixed(0)}% • ${o['distance_label'] ?? 'unknown distance'}',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ));
                      }).toList()),
              ),
            )),
          ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _speakObjects,
        icon: const Icon(Icons.record_voice_over),
        label: const Text('Speak objects'),
      ),
    );
  }
}
