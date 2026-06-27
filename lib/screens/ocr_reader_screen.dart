import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';

class OCRReaderScreen extends StatefulWidget {
  const OCRReaderScreen({super.key});
  @override
  State<OCRReaderScreen> createState() => _OCRReaderScreen();
}

class _OCRReaderScreen extends State<OCRReaderScreen> {
  File? pickImg;
  String recognizedText = "No text recognized yet";
  bool isLoading = false;
  bool isSpeaking = false;
  
  final TextRecognizer recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5); // Slower for accessibility
    await _tts.setPitch(1.0);
    
    _tts.setStartHandler(() {
      setState(() => isSpeaking = true);
    });
    
    _tts.setCompletionHandler(() {
      setState(() => isSpeaking = false);
    });
    
    _tts.setErrorHandler((msg) {
      setState(() => isSpeaking = false);
    });
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final result = await _picker.pickImage(source: source);
      if (result != null) {
        setState(() {
          pickImg = File(result.path);
          recognizedText = "Image selected. Tap 'Recognize Text' to scan.";
        });
        await _tts.stop(); // Stop speaking if new image picked
      }
    } catch (e) {
      setState(() => recognizedText = "Error picking image: $e");
    }
  }

  Future<void> recognizeText() async {
    if (pickImg == null) {
      setState(() => recognizedText = "Please select an image first");
      return;
    }

    setState(() => isLoading = true);
    await _tts.stop(); // Stop any ongoing speech

    try {
      final InputImage inputImage = InputImage.fromFilePath(pickImg!.path);
      final RecognizedText result = await recognizer.processImage(inputImage);
      
      setState(() {
        recognizedText = result.text.isEmpty 
            ? "No text found in image" 
            : result.text;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        recognizedText = "Error recognizing text: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _speak() async {
    if (recognizedText.isEmpty || recognizedText.contains("No text")) {
      await _tts.speak("No text available to read");
      return;
    }
    
    if (isSpeaking) {
      await _tts.stop();
    } else {
      await _tts.speak(recognizedText);
    }
  }

  @override
  void dispose() {
    recognizer.close();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Text Recognition"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Image preview
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: pickImg == null
                  ? const Center(child: Text("No image selected"))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(pickImg!, fit: BoxFit.cover),
                    ),
            ),

            const SizedBox(height: 20),

            // Camera + Gallery buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Recognize button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : recognizeText,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Recognize Text", style: TextStyle(fontSize: 18)),
              ),
            ),

            const SizedBox(height: 12),

            // READ ALOUD BUTTON - NEW
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _speak,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSpeaking ? Colors.red : const Color(0xff15157D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: Icon(isSpeaking ? Icons.stop : Icons.volume_up, size: 28),
                label: Text(
                  isSpeaking ? "Stop Reading" : "Read Aloud",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Display recognized text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Recognized Text:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    recognizedText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}