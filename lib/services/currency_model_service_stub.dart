import 'dart:typed_data';

class CurrencyModelService {
  bool get isSupported => false;
  bool get isModelLoaded => false;
  String get unsupportedMessage =>
      'Currency prediction is not configured for this platform.';

  Future<void> loadModel() async {
    throw UnsupportedError(unsupportedMessage);
  }

  Future<CurrencyPrediction> predictImage(Uint8List imageBytes) async {
    throw UnsupportedError(unsupportedMessage);
  }

  void close() {}
}

class CurrencyPrediction {
  const CurrencyPrediction({
    required this.label,
    required this.confidence,
  });

  final String label;
  final double confidence;
}
