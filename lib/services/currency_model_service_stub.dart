import 'dart:typed_data';

class CurrencyModelService {
  String? unsupportedMessage;

  bool get isSupported => false;
  bool get isModelLoaded => false;
  List<String> get labels => const [];

  Future<void> loadModel() async {
    throw UnsupportedError(
      'Currency recognition is not implemented for this platform.',
    );
  }

  List<double> predict(List<List<List<List<double>>>> input) {
    throw UnsupportedError(
      'Currency recognition is not implemented for this platform.',
    );
  }

  void close() {}

  Future<Object?> predictImage(Uint8List bytes) async {}
}
