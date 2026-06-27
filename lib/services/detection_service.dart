import 'dart:convert';
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
    _isStreaming = true;
    debugPrint("Detection Service Started");

    cameraService.controller.startImageStream((CameraImage image) {
      if (!_isStreaming || _isProcessing) return;

      _isProcessing = true;
      _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      // Use compute to perform heavy conversion in a separate isolate
      final Uint8List? jpegBytes = await compute(_convertYUV420toJPEG, {
        'planes': image.planes.map((p) => {
          'bytes': p.bytes,
          'bytesPerRow': p.bytesPerRow,
          'bytesPerPixel': p.bytesPerPixel,
        }).toList(),
        'width': image.width,
        'height': image.height,
      });
      
      if (jpegBytes != null && _isStreaming) {
        debugPrint("Sending frame to backend (${jpegBytes.length} bytes)");
        final base64Frame = base64Encode(jpegBytes);
        socketService.send(base64Frame);
      }
    } catch (e) {
      debugPrint("Error processing image: $e");
    } finally {
      // Throttle: wait a bit before next frame to not overwhelm backend
      await Future.delayed(const Duration(milliseconds: 100));
      _isProcessing = false;
    }
  }

  void stop() {
    _isStreaming = false;
    if (cameraService.controller.value.isStreamingImages) {
      cameraService.controller.stopImageStream();
    }
    debugPrint("Detection Service Stopped");
  }
}

// Global function for compute
Uint8List? _convertYUV420toJPEG(Map<String, dynamic> data) {
  try {
    final List<dynamic> planesData = data['planes'];
    final int width = data['width'];
    final int height = data['height'];

    final img.Image imgObj = img.Image(width: width, height: height);

    final Uint8List yBuffer = planesData[0]['bytes'];
    final Uint8List uBuffer = planesData[1]['bytes'];
    final Uint8List vBuffer = planesData[2]['bytes'];

    final int yRowStride = planesData[0]['bytesPerRow'];
    final int uvRowStride = planesData[1]['bytesPerRow'];
    final int uvPixelStride = planesData[1]['bytesPerPixel'] ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);

        // Check bounds
        if (yIndex >= yBuffer.length || uvIndex >= uBuffer.length || uvIndex >= vBuffer.length) {
          continue;
        }

        final int yp = yBuffer[yIndex];
        final int up = uBuffer[uvIndex];
        final int vp = vBuffer[uvIndex];

        // Faster YUV to RGB conversion
        int r = (yp + (1.370705 * (vp - 128))).toInt().clamp(0, 255);
        int g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128))).toInt().clamp(0, 255);
        int b = (yp + (1.732446 * (up - 128))).toInt().clamp(0, 255);

        imgObj.setPixelRgb(x, y, r, g, b);
      }
    }

    // Lower quality for faster transmission and processing
    return Uint8List.fromList(img.encodeJpg(imgObj, quality: 40));
  } catch (e) {
    debugPrint("Isolate conversion error: $e");
    return null;
  }
}
