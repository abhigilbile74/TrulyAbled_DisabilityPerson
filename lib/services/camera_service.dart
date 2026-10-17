import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  CameraController get controller {
    final value = _controller;
    if (value == null) throw StateError('Camera has not been initialized.');
    return value;
  }

  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('No camera is available.');
    final back = cameras.where((c) => c.lensDirection == CameraLensDirection.back);
    final selected = !kIsWeb && back.isNotEmpty ? back.first : cameras.first;

    await _controller?.dispose();
    _controller = CameraController(
      selected, ResolutionPreset.medium, enableAudio: false,
    );
    try {
      await _controller!.initialize();
    } catch (_) {
      await _controller?.dispose();
      _controller = null;
      rethrow;
    }
  }

  Future<void> dispose() async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
  }
}
