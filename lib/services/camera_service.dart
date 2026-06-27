import 'dart:io';
import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;

  CameraController get controller => _controller!;

  Future<void> initialize() async {
    final cameras = await availableCameras();

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
  }

  Future<void> dispose() async {
    await _controller?.dispose();
  }
}