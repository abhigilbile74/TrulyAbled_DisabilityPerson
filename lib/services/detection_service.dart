
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'camera_service.dart';
import 'websocket_service.dart';

class DetectionService {
  final CameraService cameraService;
  final WebSocketService socketService;

  bool _isStreaming = false;
  bool _isProcessing = false;

  DetectionService({
    required this.cameraService,
    required this.socketService,
  });

  Future<void> start() async {
    if (_isStreaming) return;

    final controller = cameraService.controller;

    if (!controller.value.isInitialized) {
      throw StateError('Camera is not initialized.');
    }

    if (controller.value.isStreamingImages) {
      throw StateError('Camera image stream is already running.');
    }

    _isStreaming = true;
    debugPrint('Detection Service Started');

    try {
      await controller.startImageStream((CameraImage image) {
        if (!_isStreaming || _isProcessing) return;

        _isProcessing = true;
        _processImage(image);
      });
    } catch (_) {
      _isStreaming = false;
      rethrow;
    }
  }

  Future<void> _processImage(CameraImage cameraImage) async {
    try {
      final planes = cameraImage.planes.map((plane) {
        return <String, dynamic>{
          'bytes': plane.bytes,
          'bytesPerRow': plane.bytesPerRow,
          'bytesPerPixel': plane.bytesPerPixel ?? 1,
        };
      }).toList();

      final jpegBytes = await compute(
        convertImageToJpeg,
        <String, dynamic>{
          'planes': planes,
          'width': cameraImage.width,
          'height': cameraImage.height,
          'format': cameraImage.format.group.name,
        },
      );

      if (jpegBytes != null && _isStreaming) {
        socketService.send(base64Encode(jpegBytes));
      }
    } catch (e, stackTrace) {
      debugPrint('Error processing camera frame: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _isProcessing = false;
    }
  }

  Future<void> stop() async {
    _isStreaming = false;

    try {
      final controller = cameraService.controller;

      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('Error stopping camera stream: $e');
    }

    debugPrint('Detection Service Stopped');
  }
}

// Must remain a top-level function so compute() can run it in an isolate.
Uint8List? convertImageToJpeg(Map<String, dynamic> data) {
  try {
    final planes = data['planes'] as List<dynamic>;
    final width = data['width'] as int;
    final height = data['height'] as int;
    final format = data['format'] as String;

    if (planes.isEmpty || width <= 0 || height <= 0) {
      return null;
    }

    final output = img.Image(width: width, height: height);

    if (format == 'yuv420') {
      if (planes.length < 3) return null;

      final yPlane = planes[0] as Map<String, dynamic>;
      final uPlane = planes[1] as Map<String, dynamic>;
      final vPlane = planes[2] as Map<String, dynamic>;

      final yBytes = yPlane['bytes'] as Uint8List;
      final uBytes = uPlane['bytes'] as Uint8List;
      final vBytes = vPlane['bytes'] as Uint8List;

      final yRowStride = yPlane['bytesPerRow'] as int;
      final uRowStride = uPlane['bytesPerRow'] as int;
      final vRowStride = vPlane['bytesPerRow'] as int;

      final uPixelStride = uPlane['bytesPerPixel'] as int;
      final vPixelStride = vPlane['bytesPerPixel'] as int;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yRowStride + x;
          final uIndex = (y ~/ 2) * uRowStride +
              (x ~/ 2) * uPixelStride;
          final vIndex = (y ~/ 2) * vRowStride +
              (x ~/ 2) * vPixelStride;

          if (yIndex >= yBytes.length ||
              uIndex >= uBytes.length ||
              vIndex >= vBytes.length) {
            continue;
          }

          final yp = yBytes[yIndex].toDouble();
          final up = uBytes[uIndex].toDouble() - 128.0;
          final vp = vBytes[vIndex].toDouble() - 128.0;

          final r = (yp + 1.402 * vp).round().clamp(0, 255);
          final g = (yp - 0.344136 * up - 0.714136 * vp)
              .round()
              .clamp(0, 255);
          final b = (yp + 1.772 * up).round().clamp(0, 255);

          output.setPixelRgb(x, y, r, g, b);
        }
      }
    } else if (format == 'bgra8888') {
      final plane = planes[0] as Map<String, dynamic>;
      final bytes = plane['bytes'] as Uint8List;
      final rowStride = plane['bytesPerRow'] as int;
      final pixelStride = plane['bytesPerPixel'] as int;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final index = y * rowStride + x * pixelStride;

          if (index + 2 >= bytes.length) continue;

          final b = bytes[index];
          final g = bytes[index + 1];
          final r = bytes[index + 2];

          output.setPixelRgb(x, y, r, g, b);
        }
      }
    } else {
      return null;
    }

    return Uint8List.fromList(
      img.encodeJpg(output, quality: 40),
    );
  } catch (_) {
    // Return null if the camera frame cannot be converted.
    return null;
  }
}
