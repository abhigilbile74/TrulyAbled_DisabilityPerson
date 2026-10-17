import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CurrencyModelService {
  // Chrome on same laptop: localhost.
  // Android emulator: 10.0.2.2.
  // Physical phone: change to your laptop's LAN IP, e.g. http://192.168.1.20:8000.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'CURRENCY_API_URL',
    defaultValue: '',
  );

  String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  bool _available = false;
  bool get isSupported => true;
  bool get isModelLoaded => _available;
  String get unsupportedMessage =>
      'Currency API is not reachable. Start the backend and check its URL.';

  Future<void> loadModel() async {
    final response = await http
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw StateError(
        'Currency API health check failed (${response.statusCode}).',
      );
    }
    _available = true;
  }

  
Future<CurrencyPrediction> predictImage(Uint8List imageBytes) async {
  if (!_available) {
    await loadModel();
  }

  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/predict'),
  );

  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'banknote.jpg',
    ),
  );

  final streamedResponse = await request.send().timeout(
    const Duration(seconds: 60),
  );

  final response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode != 200) {
    throw Exception(
      'Currency backend error ${response.statusCode}: ${response.body}',
    );
  }

  final dynamic decoded = jsonDecode(response.body);

  if (decoded is! Map) {
    throw const FormatException(
      'Invalid response received from currency backend.',
    );
  }

  return CurrencyPrediction(
    label: (decoded['label'] ?? 'Unable to identify denomination')
        .toString(),
    confidence: ((decoded['confidence'] as num?)?.toDouble() ?? 0.0)
        .clamp(0.0, 1.0)
        .toDouble(),
    denomination: (decoded['denomination'] as num?)?.toInt(),
    currency: (decoded['currency'] ?? 'INR').toString(),
    details: (decoded['details'] ?? '').toString(),
    recognizedText: decoded['recognized_text'] is List
        ? (decoded['recognized_text'] as List)
            .map((item) => item.toString())
            .toList()
        : <String>[],
    authenticityVerified: decoded['authenticity_verified'] == true,
  );
}

  void close() {}
}

class CurrencyPrediction {
  const CurrencyPrediction({
    required this.label,
    required this.confidence,
    required this.currency,
    required this.details,
    required this.recognizedText,
    required this.authenticityVerified,
    this.denomination,
  });

  final String label;
  final double confidence;
  final int? denomination;
  final String currency;
  final String details;
  final List<String> recognizedText;
  final bool authenticityVerified;
}
