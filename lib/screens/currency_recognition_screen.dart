
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

class _CurrencyRecognitionScreenState
    extends State<CurrencyRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  final CurrencyModelService _model = CurrencyModelService();
  final FlutterTts _tts = FlutterTts();

  CameraController? _cameraController;
  Uint8List? _selectedImageBytes;

  bool _cameraReady = false;
  bool _modelReady = false;
  bool _busy = false;
  bool _speaking = false;

  String _result = 'No currency detected';
  String _details = 'Choose a photo or capture a banknote to begin.';
  String? _message;
  double _confidence = 0;

  @override
  void initState() {
    super.initState();
    _setupTts();
    _initializeModel();
    _initializeCamera();
  }

  Future<void> _setupTts() async {
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.45);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
    } catch (e) {
      debugPrint('TTS setup failed: $e');
    }
  }

  Future<void> _initializeModel() async {
    try {
      await _model.loadModel();
      if (!mounted) return;
      setState(() {
        _modelReady = true;
        _message = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _modelReady = false;
        _message = _model.unsupportedMessage;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _message = 'No camera found. Choose an image instead.');
        }
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
    } catch (e) {
      debugPrint('Camera unavailable: $e');
      if (mounted) {
        setState(() {
          _cameraReady = false;
          _message = 'Camera unavailable. You can still select a photo from '
              'your gallery or computer.';
        });
      }
    }
  }

  Future<void> _chooseGalleryImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedImageBytes = bytes;
        _result = 'Image selected';
        _details = 'Tap “Recognize Currency” to analyze this image.';
        _confidence = 0;
        _message = _modelReady
            ? null
            : 'Image selected successfully. Prediction is not available '
                'until a compatible model or API is configured.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = 'Could not open the image: $e');
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        !_cameraReady) {
      setState(() {
        _message = 'Camera unavailable. Use “Choose from Gallery” instead.';
      });
      return;
    }

    try {
      final XFile photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _result = 'Image captured';
        _details = 'Tap “Recognize Currency” to analyze this image.';
        _confidence = 0;
        _message = _modelReady
            ? null
            : 'Photo captured, but prediction needs a compatible model/API.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not capture photo. Choose an image from the gallery.';
      });
    }
  }

  Future<void> _recognizeSelectedImage() async {
    final bytes = _selectedImageBytes;
    if (bytes == null) {
      _showMessage('Choose or capture a banknote image first.');
      return;
    }
    if (!_modelReady) {
      _showMessage(
        'The image is ready, but recognition is not configured. Add a trained '
        'model or connect a backend prediction API.',
      );
      return;
    }
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
      _result = 'Analyzing...';
    });

    try {
      final prediction = await _model.predictImage(bytes);
      final isConfident = prediction.confidence >= 0.70;
      final label = _formatLabel(prediction.label);

      if (!mounted) return;
      setState(() {
        _result = isConfident ? label : 'Uncertain result';
        _confidence = prediction.confidence;
        _details = isConfident
            ? 'Possible denomination: $label. Authenticity has not been verified.'
            : 'Try a clearer photo with better lighting.';
      });
      if (isConfident) {
        await _speak('$label detected. Authenticity has not been verified.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = 'Recognition failed';
        _details = 'Try another clear image.';
        _message = 'Prediction failed. Confirm that model input processing '
            'and labels match your trained model.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatLabel(String label) {
    final clean = label.trim().replaceAll('₹', '').replaceAll('Rs.', '').trim();
    return RegExp(r'^\d+$').hasMatch(clean) ? '₹$clean' : label;
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      if (mounted) setState(() => _speaking = true);
      await _tts.speak(text);
    } catch (e) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _toggleSpeech() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
    } else {
      await _speak('$_result. $_details. Authenticity has not been verified.');
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _clearImage() {
    setState(() {
      _selectedImageBytes = null;
      _result = 'No currency detected';
      _details = 'Choose a photo or capture a banknote to begin.';
      _confidence = 0;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _model.close();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF20246B);
    const teal = Color(0xFF087F8C);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      appBar: AppBar(
        title: const Text(
          'Currency Recognition',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: navy,
        backgroundColor: const Color(0xFFF6F8FF),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 280,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF171A35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _selectedImageBytes != null
                  ? Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    )
                  : _cameraReady &&
                          _cameraController != null &&
                          _cameraController!.value.isInitialized
                      ? CameraPreview(_cameraController!)
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image_search,
                                  color: Colors.white, size: 54),
                              SizedBox(height: 12),
                              Text(
                                'Choose a banknote photo',
                                style: TextStyle(color: Colors.white),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Camera optional',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseGalleryImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from Gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || !_cameraReady ? null : _capturePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Photo'),
                ),
                if (_selectedImageBytes != null)
                  TextButton.icon(
                    onPressed: _busy ? null : _clearImage,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: navy.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'DETECTED DENOMINATION',
                    style: TextStyle(
                      color: teal,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _result,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_details, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Model score')),
                      Text('${(_confidence * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _confidence,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: teal,
                    backgroundColor: const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Authenticity is not verified by this feature.',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _busy || _selectedImageBytes == null
                    ? null
                    : _recognizeSelectedImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.document_scanner),
                label: Text(_busy ? 'Analyzing...' : 'Recognize Currency'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _toggleSpeech,
              icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
              label: Text(_speaking ? 'Stop Speech' : 'Speak Result'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Use a clear, well-lit image with the entire banknote visible. '
              'The displayed model score is not necessarily a calibrated '
              'probability and does not confirm that a note is genuine.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
