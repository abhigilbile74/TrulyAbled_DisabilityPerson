import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _speechEnabled = false;
  bool _isListening = false;
  String _recognizedWords = "Tap mic and start speaking";
  String _confidenceLevel = "";
  double _soundLevel = 0.0;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseAnimation = Tween(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initSpeech();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-IN");
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      setState(() => _recognizedWords = "Microphone permission denied");
      return;
    }

    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          _pulseController.stop();
        }
      },
      onError: (error) {
        setState(() {
          _isListening = false;
          _recognizedWords = "Error: $error";
        });
        _pulseController.stop();
      },
    );
    setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) return;
    
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: "en_IN", // Indian English
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = level);
      },
      cancelOnError: true,
      partialResults: true,
    );
    
    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);
    Vibration.vibrate(duration: 100);
    await _tts.speak("Listening");
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
    _pulseController.stop();
    Vibration.vibrate(duration: 100);
    await _tts.speak("Stopped listening");
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _recognizedWords = result.recognizedWords;
      if (result.hasConfidenceRating && result.confidence > 0) {
        _confidenceLevel = "${(result.confidence * 100).toStringAsFixed(0)}% confident";
      }
    });
  }

  Future<void> _speakText() async {
    if (_recognizedWords.isEmpty || _recognizedWords.contains("Tap mic")) {
      await _tts.speak("No text to read");
      return;
    }
    await _tts.speak(_recognizedWords);
  }

  void _clearText() {
    setState(() {
      _recognizedWords = "Tap mic and start speaking";
      _confidenceLevel = "";
    });
    Vibration.vibrate(duration: 50);
  }

  @override
  void dispose() {
    _speechToText.stop();
    _tts.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8f9ff),
      appBar: AppBar(
        backgroundColor: const Color(0xfff8f9ff),
        elevation: 0,
        title: const Text(
          "Speech to Text",
          style: TextStyle(color: Color(0xff15157d), fontSize: 28, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xff15157d)),
            onPressed: () => _showHelp(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Sound level indicator
                  if (_isListening)
                    Container(
                      height: 8,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: LinearProgressIndicator(
                        value: _soundLevel.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _soundLevel > 0.3 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),

                  // Text display card
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 300),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isListening ? const Color(0xff006a6a) : Colors.grey.shade300,
                        width: _isListening ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: _isListening ? const Color(0xff006a6a) : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isListening ? "Listening..." : "Not listening",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isListening ? const Color(0xff006a6a) : Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            if (_confidenceLevel.isNotEmpty)
                              Text(_confidenceLevel, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          _recognizedWords,
                          style: TextStyle(
                            fontSize: _recognizedWords.length > 100 ? 20 : 24,
                            color: const Color(0xff121c2a),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearText,
                          icon: const Icon(Icons.clear),
                          label: const Text("Clear"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xff15157d)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _speakText,
                          icon: const Icon(Icons.volume_up),
                          label: const Text("Read Aloud"),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xff15157d),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Mic button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xffe6eeff),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Text(
                  _isListening ? "Tap to stop" : "Tap to speak",
                  style: const TextStyle(fontSize: 18, color: Color(0xff464652)),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _speechToText.isNotListening ? _startListening : _stopListening,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isListening ? _pulseAnimation.value : 1.0,
                        child: Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? const Color(0xff006a6a) : const Color(0xff2e3192),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? Colors.green : Colors.blue).withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: _isListening ? 10 : 5,
                              )
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _speechEnabled ? "Ready" : "Speech not available",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("How to Use"),
        content: const Text(
          "1. Tap the mic button\n"
          "2. Speak clearly\n"
          "3. Text appears automatically\n"
          "4. Tap 'Read Aloud' to hear it\n"
          "5. Tap 'Clear' to start over\n\n"
          "Works offline for basic commands.\n"
          "Best results in quiet environment.",
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it"))],
      ),
    );
  }
}