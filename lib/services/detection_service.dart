import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'camera_service.dart';
import 'websocket_service.dart';

/// Captures JPEG snapshots instead of converting CameraImage planes.
/// This is more portable across camera_web and mobile than manual YUV/BGRA conversion.
class DetectionService {
  DetectionService({
    required this.cameraService,
    required this.socketService,
    this.interval = const Duration(milliseconds: 800),
  });

  final CameraService cameraService;
  final WebSocketService socketService;
  final Duration interval;
  Timer? _timer;
  bool _running = false;
  bool _capturing = false;

  Future<void> start() async {
    if (_running) return;
    if (!cameraService.controller.value.isInitialized) {
      throw StateError('Camera is not initialized.');
    }
    _running = true;
    _timer = Timer.periodic(interval, (_) => _capture());
  }

  Future<void> _capture() async {
    if (!_running || _capturing) return;
    final camera = cameraService.controller;
    if (!camera.value.isInitialized || camera.value.isTakingPicture) return;
    _capturing = true;
    try {
      final photo = await camera.takePicture();
      final bytes = await photo.readAsBytes();
      if (_running && bytes.isNotEmpty) {
        socketService.send(base64Encode(bytes));
      }
    } catch (e) {
      debugPrint('Frame capture failed: $e');
    } finally {
      _capturing = false;
    }
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }
}
