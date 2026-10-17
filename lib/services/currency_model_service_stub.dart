import 'dart:typed_data';

class CurrencyModelService {
  bool get isSupported => false;
  bool get isModelLoaded => false;
  String get unsupportedMessage => 'Currency recognition API is not configured.';
  Future<void> loadModel() async => throw UnsupportedError(unsupportedMessage);
  Future<CurrencyPrediction> predictImage(Uint8List bytes) async =>
      throw UnsupportedError(unsupportedMessage);
  void close() {}
}

class CurrencyPrediction {
  const CurrencyPrediction({
    required this.label,
    required this.confidence,
    this.details = '',
  });
  final String label;
  final double confidence;
  final String details;
}
