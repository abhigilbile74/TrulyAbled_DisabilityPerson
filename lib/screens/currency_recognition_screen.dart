import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';

import '../services/currency_model_service.dart';

class CurrencyRecognitionScreen extends StatefulWidget {
  const CurrencyRecognitionScreen({super.key});

  @override
  State<CurrencyRecognitionScreen> createState() =>
      _CurrencyRecognitionScreenState();
}

class _CurrencyRecognitionScreenState extends State<CurrencyRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  final CurrencyModelService _api = CurrencyModelService();
  final FlutterTts _tts = FlutterTts();

  CameraController? _camera;
  Uint8List? _imageBytes;
  CurrencyPrediction? _prediction;

  bool _cameraReady = false;
  bool _backendReady = false;
  bool _checkingBackend = true;
  bool _busy = false;
  bool _speaking = false;
  String? _error;
  String _status = 'Checking currency backend…';

  @override
  void initState() {
    super.initState();
    _setupTts();
    _checkBackend();
    _initializeCamera();
  }

  Future<void> _setupTts() async {
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      _tts.setErrorHandler((message) {
        if (mounted) setState(() => _speaking = false);
        debugPrint('TTS error: $message');
      });
    } catch (e) {
      debugPrint('TTS setup failed: $e');
    }
  }

  Future<void> _checkBackend() async {
    if (mounted) {
      setState(() {
        _checkingBackend = true;
        _error = null;
        _status = 'Connecting to backend…';
      });
    }
    try {
      await _api.loadModel();
      if (!mounted) return;
      setState(() {
        _backendReady = true;
        _checkingBackend = false;
        _status = 'Backend connected';
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _backendReady = false;
        _checkingBackend = false;
        _status = 'Backend not connected';
        _error = '${_api.unsupportedMessage}\nDetails: $e';
      });
    }
  }

  Future<void> _initializeCamera() async {
    CameraController? candidate;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera detected.');
      final selected = !kIsWeb
          ? cameras.where((c) => c.lensDirection == CameraLensDirection.back)
              .firstOrNull ?? cameras.first
          : cameras.first;

      candidate = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await candidate.initialize();
      if (!mounted) {
        await candidate.dispose();
        return;
      }
      setState(() {
        _camera = candidate;
        _cameraReady = true;
      });
    } catch (e) {
      await candidate?.dispose();
      debugPrint('Camera unavailable: $e');
      if (mounted) {
        setState(() {
          _cameraReady = false;
          // Gallery selection remains available when camera permissions fail.
        });
      }
    }
  }

  Future<void> _chooseImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('The selected image is empty.');
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _prediction = null;
        _error = null;
        _status = 'Image ready to analyze';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not select image: $e');
    }
  }

  Future<void> _capturePhoto() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || !_cameraReady) {
      _showMessage('Camera is unavailable. Choose a photo instead.');
      return;
    }
    try {
      final file = await camera.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _prediction = null;
        _error = null;
        _status = 'Photo ready to analyze';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not capture photo: $e');
    }
  }

  Future<void> _recognize() async {
    final bytes = _imageBytes;
    if (bytes == null) {
      _showMessage('Choose a banknote image or take a photo first.');
      return;
    }
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
      _prediction = null;
      _status = 'Analyzing banknote…';
    });

    try {
      final prediction = await _api.predictImage(bytes);
      if (!mounted) return;
      final identified = prediction.confidence > 0;
      setState(() {
        _prediction = prediction;
        _status = !identified
            ? 'Denomination not identified'
            : 'Analysis complete';
        _backendReady = true;
      });

      if (identified) {
        await _speak(
          'Possible denomination: ${prediction.label}. '
          'Please verify the note. Authenticity has not been checked.',
        );
      } else {
        await _speak(
          'I could not confidently identify the denomination. '
          'Please take a clearer photo with the entire banknote visible.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Recognition failed';
        _backendReady = false;
        _error = 'Could not analyze this image.\n$e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      if (mounted) setState(() => _speaking = true);
      await _tts.speak(text);
    } catch (e) {
      if (mounted) setState(() => _speaking = false);
      debugPrint('Speech failed: $e');
    }
  }

  Future<void> _toggleSpeech() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final result = _prediction;
    if (result == null) {
      _showMessage('Recognize a banknote first.');
      return;
    }
    await _speak(
      '${result.label}. ${result.details} '
      'Authenticity has not been verified.',
    );
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _prediction = null;
      _error = null;
      _status = _backendReady ? 'Ready for a banknote image' : 'Backend not connected';
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _camera?.dispose();
    _api.close();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF20246B);
    const teal = Color(0xFF087F8C);
    final prediction = _prediction;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      appBar: AppBar(
        title: const Text('Currency Recognition',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF5F7FC),
        foregroundColor: navy,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Check backend connection',
            onPressed: _checkingBackend ? null : _checkBackend,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ConnectionBanner(
              connected: _backendReady,
              checking: _checkingBackend,
              status: _status,
              onRetry: _checkBackend,
            ),
            const SizedBox(height: 14),
            Container(
              height: 250,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF171A35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.contain, width: double.infinity)
                  : (_cameraReady && _camera != null && _camera!.value.isInitialized)
                      ? CameraPreview(_camera!)
                      : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    color: Colors.white, size: 54),
                                SizedBox(height: 12),
                                Text('Choose a banknote photo',
                                    style: TextStyle(color: Colors.white, fontSize: 17)),
                                SizedBox(height: 5),
                                Text('Camera is optional',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose Image'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || !_cameraReady ? null : _capturePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Photo'),
                ),
                if (_imageBytes != null)
                  TextButton.icon(
                    onPressed: _busy ? null : _clearImage,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: navy.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('DETECTED DENOMINATION',
                      style: TextStyle(
                        color: teal,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      )),
                  const SizedBox(height: 12),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    )
                  else
                    Text(
                      prediction?.label ?? 'Ready to scan',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    prediction?.details ??
                        (_imageBytes == null
                            ? 'Choose or capture a clear Indian banknote image.'
                            : 'Image selected. Tap Recognize Currency to analyze it.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Expanded(child: Text('OCR score (not verified probability)')),
                      Text('${((prediction?.confidence ?? 0) * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: prediction?.confidence ?? 0,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: teal,
                    backgroundColor: const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'This feature estimates denomination from printed text. '
                    'It does not verify whether a banknote is genuine.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.deepOrange, fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _busy || _imageBytes == null ? null : _recognize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: navy.withOpacity(0.35),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(_busy ? 'Analyzing…' : 'Recognize Currency'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _toggleSpeech,
              icon: Icon(_speaking ? Icons.stop : Icons.volume_up_outlined),
              label: Text(_speaking ? 'Stop Speech' : 'Speak Result'),
            ),
            const SizedBox(height: 12),
            const Text(
              'For best results, place the full note in the frame, keep it sharp, '
              'avoid glare, and use good lighting. If the result is uncertain, '
              'do not rely on it for a financial decision.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({
    required this.connected,
    required this.checking,
    required this.status,
    required this.onRetry,
  });

  final bool connected;
  final bool checking;
  final String status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = checking
        ? Colors.blueGrey
        : connected
            ? Colors.green.shade700
            : Colors.red.shade700;
    final background = checking
        ? Colors.blueGrey.shade50
        : connected
            ? Colors.green.shade50
            : Colors.red.shade50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (checking)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(status,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
          if (!connected && !checking)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
