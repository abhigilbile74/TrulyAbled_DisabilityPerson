import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CurrencyModelService {
  static const int imageSize = 224;

  Interpreter? _interpreter;
  List<String> _labels = const [];

  bool get isSupported => true;
  bool get isModelLoaded => _interpreter != null;
  String get unsupportedMessage => 'Currency model is not loaded.';

  Future<void> loadModel() async {
    if (_interpreter != null) return;

    final interpreter = await Interpreter.fromAsset(
      'assets/models/currency_model.tflite',
    );

    try {
      final labelsText = await rootBundle.loadString(
        'assets/models/labels.txt',
      );
      final labels = labelsText
          .split(RegExp(r'\r?\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final inputShape = interpreter.getInputTensor(0).shape;
      if (inputShape.length != 4 ||
          inputShape[0] != 1 ||
          inputShape[1] != imageSize ||
          inputShape[2] != imageSize ||
          inputShape[3] != 3) {
        throw StateError(
          'This code expects model input [1, 224, 224, 3], got $inputShape.',
        );
      }

      final outputShape = interpreter.getOutputTensor(0).shape;
      if (outputShape.isEmpty || outputShape.last != labels.length) {
        throw StateError(
          'Output shape $outputShape does not match labels.txt '
          '(${labels.length} labels).',
        );
      }

      _interpreter = interpreter;
      _labels = labels;
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  Future<CurrencyPrediction> predictImage(Uint8List imageBytes) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Call loadModel() before prediction.');
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw StateError('The selected file is not a readable image.');
    }

    final oriented = img.bakeOrientation(decoded);
    final resized = img.copyResize(
      oriented,
      width: imageSize,
      height: imageSize,
      interpolation: img.Interpolation.linear,
    );

    final input = [
      List.generate(
        imageSize,
        (y) => List.generate(
          imageSize,
          (x) {
            final p = resized.getPixel(x, y);
            return [
              p.r.toDouble() / 255.0,
              p.g.toDouble() / 255.0,
              p.b.toDouble() / 255.0,
            ];
          },
        ),
      ),
    ];

    final outputSize = interpreter.getOutputTensor(0).shape.last;
    final output = [List<double>.filled(outputSize, 0)];
    interpreter.run(input, output);

    var bestIndex = 0;
    for (var i = 1; i < output.first.length; i++) {
      if (output.first[i] > output.first[bestIndex]) bestIndex = i;
    }

    return CurrencyPrediction(
      label: _labels[bestIndex],
      confidence: output.first[bestIndex].clamp(0.0, 1.0).toDouble(),
    );
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _labels = const [];
  }
}

class CurrencyPrediction {
  const CurrencyPrediction({
    required this.label,
    required this.confidence,
  });

  final String label;
  final double confidence;
}
