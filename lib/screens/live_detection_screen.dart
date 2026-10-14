import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:trulyabled/services/camera_service.dart';
import 'package:trulyabled/services/detection_service.dart';
import 'package:trulyabled/services/websocket_service.dart';
import 'package:flutter/foundation.dart';

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
    debugPrint('Initializing Camera...');
    await _cameraService.initialize();

    if (!mounted) return;

    debugPrint('Connecting to WebSocket...');

    final wsUrl = kIsWeb
        ? 'ws://localhost:8000/ws/detect'
        : 'ws://10.0.2.2:8000/ws/detect';

    await _socketService.connect(wsUrl);

    if (!mounted) return;

    // Listen for backend responses before starting detection.
    _socketService.stream.listen(
      (message) {
        try {
          debugPrint('Received message from backend: $message');

          final dynamic decoded = jsonDecode(message.toString());

          if (decoded is! Map<String, dynamic>) {
            debugPrint('Invalid backend response format.');
            return;
          }

          final dynamic result = decoded['objects'];

          if (result is! List || result.isEmpty) {
            if (mounted) {
              setState(() {
                _detectedObject = 'No object detected';
                _confidence = 0.0;
              });
            }
            return;
          }

          final dynamic topObject = result.first;

          if (topObject is! Map) return;

          final name = topObject['name']?.toString();
          final confidenceValue = topObject['confidence'];

          if (name == null || name.isEmpty) return;

          final double confidence =
              (confidenceValue as num?)?.toDouble() ?? 0.0;

          if (mounted) {
            setState(() {
              _detectedObject = name.toUpperCase();
              _confidence = confidence;
            });
          }

          _speakUpdate(name);
        } catch (e) {
          debugPrint('Error parsing detection response: $e');
        }
      },
      onError: (error) {
        debugPrint('WebSocket Error: $error');
      },
      onDone: () {
        debugPrint('WebSocket connection closed.');
      },
    );

    _detectionService = DetectionService(
      cameraService: _cameraService,
      socketService: _socketService,
    );

    debugPrint('Starting Detection Service...');
    await _detectionService!.start();

    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    debugPrint('Live detection initialized successfully.');
  } catch (e, stackTrace) {
    debugPrint('Initialization Error: $e');
    debugPrintStack(stackTrace: stackTrace);

    if (mounted) {
      setState(() {
        _isInitialized = false;
        _detectedObject = 'Initialization failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start live detection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
