
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;

  CameraController get controller {
    final current = _controller;
    if (current == null) {
      throw StateError('Camera has not been initialized.');
    }
    return current;
  }

  Future<void> initialize() async {
    final cameras = await availableCameras();

    if (cameras.isEmpty) {
      throw StateError('No cameras are available on this device.');
    }

    final backCameras = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    final selectedCamera =
        backCameras.isNotEmpty ? backCameras.first : cameras.first;

    final oldController = _controller;
    if (oldController != null) {
      await oldController.dispose();
    }

    final newController = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: kIsWeb
    ? ImageFormatGroup.bgra8888
    : defaultTargetPlatform == TargetPlatform.iOS
        ? ImageFormatGroup.bgra8888
        : ImageFormatGroup.yuv420,
    );

    _controller = newController;

    try {
      await newController.initialize();
    } catch (_) {
      await newController.dispose();
      _controller = null;
      rethrow;
    }
  }

  Future<void> dispose() async {
    final current = _controller;
    _controller = null;
    await current?.dispose();
  }
}
