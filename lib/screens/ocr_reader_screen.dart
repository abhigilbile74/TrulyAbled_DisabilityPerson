
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/ocr_service_mobile.dart'
    if (dart.library.js_interop)
        '../services/ocr_service_web.dart' as ocr;

class OCRReaderScreen extends StatefulWidget {
  const OCRReaderScreen({super.key});

  @override
  State<OCRReaderScreen> createState() => _OCRReaderScreenState();
}

class _OCRReaderScreenState extends State<OCRReaderScreen> {
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _tts = FlutterTts();

  XFile? _image;
  Uint8List? _imageBytes;

  String recognizedText = 'No text recognized yet';
  bool isLoading = false;
  bool isSpeaking = false;

  
String summarizeText(String text, {int maxSentences = 3}) {
  final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (cleaned.isEmpty) return 'No text available to summarize.';

  final sentences = cleaned
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((s) => s.trim().length > 15)
      .toList();

  if (sentences.length <= maxSentences) {
    return cleaned;
  }

  const stopWords = {
    'the', 'is', 'a', 'an', 'and', 'or', 'to', 'of', 'in',
    'on', 'for', 'with', 'that', 'this', 'it', 'are', 'was',
    'were', 'be', 'as', 'by', 'at', 'from', 'has', 'have',
  };

  final words = cleaned
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 2 && !stopWords.contains(word));

  final frequencies = <String, int>{};

  for (final word in words) {
    frequencies[word] = (frequencies[word] ?? 0) + 1;
  }

  final ranked = sentences.asMap().entries.map((entry) {
    final sentenceWords = entry.value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'));

    final score = sentenceWords.fold<int>(
      0,
      (sum, word) => sum + (frequencies[word] ?? 0),
    );

    return (
      index: entry.key,
      sentence: entry.value.trim(),
      score: score,
    );
  }).toList();

  ranked.sort((a, b) => b.score.compareTo(a.score));

  final selected = ranked.take(maxSentences).toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  return selected.map((item) => item.sentence).join(' ');
}

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      _tts.setStartHandler(() {
        if (mounted) {
          setState(() => isSpeaking = true);
        }
      });

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => isSpeaking = false);
        }
      });

      _tts.setCancelHandler(() {
        if (mounted) {
          setState(() => isSpeaking = false);
        }
      });

      _tts.setErrorHandler((message) {
        if (mounted) {
          setState(() => isSpeaking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech error: $message')),
          );
        }
      });
    } catch (e) {
      debugPrint('TTS initialization error: $e');
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? result = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (result == null) return;

      final bytes = await result.readAsBytes();

      await _tts.stop();

      if (!mounted) return;

      setState(() {
        _image = result;
        _imageBytes = bytes;
        recognizedText =
            'Image selected. Tap Recognize Text to scan.';
        isSpeaking = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image selection failed: $e')),
      );
    }
  }

  Future<void> recognizeText() async {
    if (_image == null) {
      _showMessage('Please select an image first.');
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
      recognizedText = 'Recognizing text...';
    });

    await _tts.stop();

    try {
      final text = await ocr.recognizeImage(_image!);

setState(() {
  recognizedText = text.trim().isEmpty
      ? 'No text found in image.'
      : summarizeText(text);
});
    } catch (e, stackTrace) {
      debugPrint('OCR error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        recognizedText = 'Text recognition failed. Please try another image.';
      });

      _showMessage('OCR error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _speak() async {
    if (isSpeaking) {
      await _tts.stop();

      if (mounted) {
        setState(() => isSpeaking = false);
      }
      return;
    }

    if (_image == null ||
        recognizedText == 'No text recognized yet' ||
        recognizedText.startsWith('Image selected.') ||
        recognizedText == 'Recognizing text...' ||
        recognizedText.startsWith('Text recognition failed') ||
        recognizedText.startsWith('No text found')) {
      _showMessage('Please recognize text from an image first.');
      return;
    }

    try {
      await _tts.stop();
      await _tts.speak(recognizedText);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to read text aloud: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Recognition & Reader'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _imageBytes == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text('Select an image to get started'),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () => pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : recognizeText,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.document_scanner),
                label: Text(
                  isLoading ? 'Recognizing...' : 'Recognize Text',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _speak,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSpeaking
                      ? Colors.red
                      : const Color(0xff15157D),
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  isSpeaking ? Icons.stop : Icons.volume_up,
                ),
                label: Text(
                  isSpeaking ? 'Stop Reading' : 'Read Aloud',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Recognized Text',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                recognizedText,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
