import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:trulyabled/services/camera_service.dart';
import 'package:trulyabled/services/detection_service.dart';
import 'package:trulyabled/services/websocket_service.dart';

class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({super.key});

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  final CameraService _cameraService = CameraService();
  final WebSocketService _socketService = WebSocketService();
  final FlutterTts _flutterTts = FlutterTts();
  
  DetectionService? _detectionService;

  String _detectedObject = "Scanning...";
  double _confidence = 0.0;
  bool _isInitialized = false;
  String? _lastSpoken;
  DateTime? _lastSpokenTime;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      debugPrint("Initializing Camera...");
      await _cameraService.initialize();

      debugPrint("Connecting to WebSocket...");
      _socketService.connect("ws://10.0.2.2:8000/ws/detect");

      _detectionService = DetectionService(
        cameraService: _cameraService,
        socketService: _socketService,
      );

      debugPrint("Starting Detection Service...");
      await _detectionService!.start();

      _socketService.stream.listen((message) {
        debugPrint("Received message from backend: $message");
        final data = jsonDecode(message);
        final List objects = data["objects"] ?? [];

        if (objects.isNotEmpty) {
          final topObject = objects[0];
          final String name = topObject["name"];
          final double conf = topObject["confidence"];

          if (mounted) {
            setState(() {
              _detectedObject = name.toUpperCase();
              _confidence = conf;
            });
          }

          _speakUpdate(name);
        }
      }, onError: (error) {
        debugPrint("WebSocket Error: $error");
      });

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Initialization Error: $e");
    }
  }

  Future<void> _speakUpdate(String text) async {
    // Only speak if it's a new object or 3 seconds have passed
    final now = DateTime.now();
    if (_lastSpoken != text || (_lastSpokenTime == null || now.difference(_lastSpokenTime!).inSeconds > 3)) {
      _lastSpoken = text;
      _lastSpokenTime = now;
      await _flutterTts.speak(text);
    }
  }

  @override
  void dispose() {
    _detectionService?.stop();
    _socketService.close();
    _cameraService.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || !_cameraService.controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Object Detection"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_cameraService.controller),
          ),

          // Detection Overlay
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.deepPurple, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _detectedObject,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Confidence: ${(_confidence * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
