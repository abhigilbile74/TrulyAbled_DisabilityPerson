// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:vibration/vibration.dart';
// import 'package:image/image.dart' as img;
// import '../services/camera_service.dart';

import 'package:flutter/material.dart';

class CurrencyRecognitionScreen extends StatelessWidget{
  const CurrencyRecognitionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}


// class CurrencyRecognitionScreen extends StatefulWidget {
//   const CurrencyRecognitionScreen({super.key});

//   @override
//   State<CurrencyRecognitionScreen> createState() => _CurrencyRecognitionScreenState();
// }

// class _CurrencyRecognitionScreenState extends State<CurrencyRecognitionScreen>
//     with SingleTickerProviderStateMixin {
//   final CameraService cameraService = CameraService();
//   final FlutterTts _tts = FlutterTts();
  
//   late AnimationController scanController;
//   late Animation<double> scanAnimation;
  
//   Interpreter? _interpreter;
//   List<String> _labels = [];
//   bool _modelLoaded = false;
  
//   String detectedValue = "₹0";
//   String detectedNote = "No note detected";
//   double confidence = 0.0;
//   bool speaking = false;
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     cameraService.initialize().then((_) => setState(() {}));
//     scanController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
//     scanAnimation = Tween<double>(begin: 0, end: 1).animate(scanController);
//     _initTts();
//     _loadModel();
//     _startDetectionLoop();
//   }

//   Future<void> _initTts() async {
//     await _tts.setLanguage("en-IN"); // Indian English
//     await _tts.setSpeechRate(0.5);
//     await _tts.setPitch(1.0);
//   }

//   Future<void> _loadModel() async {
//     try {
//       _interpreter = await Interpreter.fromAsset('assets/models/currency_model.tflite');
//       final labelsData = await DefaultAssetBundle.of(context).loadString('assets/models/labels.txt');
//       _labels = labelsData.split('\n');
//       setState(() => _modelLoaded = true);
//     } catch (e) {
//       print('Model load error: $e');
//     }
//   }

//   void _startDetectionLoop() {
//     Future.delayed(const Duration(milliseconds: 500), () async {
//       if (!mounted || !_modelLoaded || !cameraService.controller.value.isInitialized) {
//         _startDetectionLoop();
//         return;
//       }
//       await _runDetection();
//       _startDetectionLoop();
//     });
//   }

//   Future<void> _runDetection() async {
//     if (_isProcessing) return;
//     _isProcessing = true;

//     try {
//       final file = await cameraService.controller.takePicture();
//       final bytes = await file.readAsBytes();
//       final image = img.decodeImage(bytes);
//       if (image == null) return;

//       // Preprocess: resize to 224x224, normalize
//       final resized = img.copyResize(image, width: 224, height: 224);
//       final input = _imageToByteListFloat32(resized, 224);

//       // Run inference
//       final output = List.filled(1 * _labels.length, 0.0).reshape([1, _labels.length]);
//       _interpreter!.run(input.reshape([1, 224, 224, 3]), output);

//       // Get highest confidence
//       final results = output[0] as List<double>;
//       double maxConf = 0;
//       int maxIndex = 0;
//       for (int i = 0; i < results.length; i++) {
//         if (results[i] > maxConf) {
//           maxConf = results[i];
//           maxIndex = i;
//         }
//       }

//       if (maxConf > 0.65 && mounted) {
//         final note = _labels[maxIndex];
//         setState(() {
//           detectedValue = "₹$note";
//           detectedNote = _getNoteDescription(note);
//           confidence = maxConf;
//         });

//         // Vibrate on new detection
//         if (await Vibration.hasVibrator() == true) {
//           Vibration.vibrate(duration: 100);
//         }
//       }
//     } catch (e) {
//       print('Detection error: $e');
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   List<List<List<List<double>>>> _imageToByteListFloat32(img.Image image, int size) {
//     var convertedBytes = List.generate(
//       1,
//       (index) => List.generate(
//         size,
//         (y) => List.generate(
//           size,
//           (x) {
//             final pixel = image.getPixel(x, y);
//             return [
//               (pixel.r / 255.0),
//               (pixel.g / 255.0),
//               (pixel.b / 255.0),
//             ];
//           },
//         ),
//       ),
//     );
//     return convertedBytes;
//   }

//   String _getNoteDescription(String value) {
//     switch (value) {
//       case "10": return "Brown 10 Rupee note with Sun Temple";
//       case "20": return "Greenish Yellow 20 Rupee note with Ellora Caves";
//       case "50": return "Fluorescent Blue 50 Rupee note with Hampi";
//       case "100": return "Lavender 100 Rupee note with Rani Ki Vav";
//       case "200": return "Bright Yellow 200 Rupee note with Sanchi Stupa";
//       case "500": return "Stone Grey 500 Rupee note with Red Fort";
//       case "2000": return "Magenta 2000 Rupee note with Mangalyaan";
//       default: return "Indian banknote detected";
//     }
//   }

//   Future<void> speakResult() async {
//     if (speaking) {
//       await _tts.stop();
//       setState(() => speaking = false);
//       return;
//     }

//     setState(() => speaking = true);
//     await _tts.speak("$detectedValue detected. $detectedNote");
    
//     _tts.setCompletionHandler(() {
//       if (mounted) setState(() => speaking = false);
//     });
//   }

//   @override
//   void dispose() {
//     scanController.dispose();
//     cameraService.dispose();
//     _interpreter?.close();
//     _tts.stop();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xfff8f9ff),
//       appBar: AppBar(
//         backgroundColor: const Color(0xfff8f9ff),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Color(0xff15157d)),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text(
//           "Currency Recognition",
//           style: TextStyle(color: Color(0xff15157d), fontSize: 22, fontWeight: FontWeight.w600),
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.help, color: Color(0xff15157d)),
//             onPressed: () => _showHelpDialog(),
//           )
//         ],
//       ),
//       body: Stack(
//         children: [
//           SingleChildScrollView(
//             padding: const EdgeInsets.only(bottom: 100),
//             child: Column(
//               children: [
//                 cameraPreview(),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Column(
//                     children: [
//                       const SizedBox(height: 20),
//                       detectionCard(),
//                       const SizedBox(height: 20),
//                       chips(),
//                       const SizedBox(height: 25),
//                       actions(),
//                       const SizedBox(height: 20),
//                       insight(),
//                     ],
//                   ),
//                 )
//               ],
//             ),
//           ),
//           bottomNav()
//         ],
//       ),
//     );
//   }

//   Widget cameraPreview() {
//     return SizedBox(
//       height: 400,
//       width: double.infinity,
//       child: Stack(
//         children: [
//           cameraService.controller.value.isInitialized
//               ? CameraPreview(cameraService.controller)
//               : Container(color: Colors.black),
//           Center(
//             child: Container(
//               width: 300,
//               height: 200,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: const Color(0xff90efef), width: 2),
//               ),
//               child: Stack(
//                 children: [
//                   AnimatedBuilder(
//                     animation: scanAnimation,
//                     builder: (context, child) {
//                       return Positioned(
//                         top: 200 * scanAnimation.value,
//                         left: 0,
//                         right: 0,
//                         child: Container(
//                           height: 2,
//                           decoration: const BoxDecoration(
//                             gradient: LinearGradient(
//                               colors: [Colors.transparent, Color(0xff90efef), Colors.transparent],
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: 15,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
//                 decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
//                 child: Text(
//                   _modelLoaded ? "Hold steady to recognize banknote" : "Loading model...",
//                   style: const TextStyle(color: Colors.white, fontSize: 12),
//                 ),
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }

//   Widget detectionCard() {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: const Color(0xffeff4ff),
//         borderRadius: BorderRadius.circular(18),
//         border: const Border(left: BorderSide(color: Color(0xff006a6a), width: 5)),
//       ),
//       child: Column(
//         children: [
//           const Text("DETECTED VALUE", style: TextStyle(color: Color(0xff006a6a), fontWeight: FontWeight.bold)),
//           const SizedBox(height: 10),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(
//                 detectedValue,
//                 style: const TextStyle(color: Color(0xff15157d), fontSize: 32, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(width: 8),
//               Text(
//                 confidence > 0.65 ? "detected" : "scanning...",
//                 style: const TextStyle(fontSize: 22),
//               )
//             ],
//           ),
//           const SizedBox(height: 15),
//           LinearProgressIndicator(
//             value: confidence,
//             color: const Color(0xff006a6a),
//             backgroundColor: const Color(0xffd9e3f6),
//           )
//         ],
//       ),
//     );
//   }

//   Widget chips() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text("Common Indian Banknotes", style: TextStyle(color: Colors.grey)),
//         const SizedBox(height: 10),
//         Wrap(
//           spacing: 10,
//           children: [
//             chip("₹10", detectedValue == "₹10"),
//             chip("₹20", detectedValue == "₹20"),
//             chip("₹50", detectedValue == "₹50"),
//             chip("₹100", detectedValue == "₹100"),
//             chip("₹200", detectedValue == "₹200"),
//             chip("₹500", detectedValue == "₹500"),
//             chip("₹2000", detectedValue == "₹2000"),
//           ],
//         )
//       ],
//     );
//   }

//   Widget chip(String text, bool active) {
//     return Chip(
//       label: Text(
//         text,
//         style: TextStyle(
//           color: active ? Colors.white : const Color(0xff006a6a),
//           fontWeight: FontWeight.bold,
//         ),
//       ),
//       backgroundColor: active ? const Color(0xff2e3192) : const Color(0xff90efef),
//     );
//   }

//   Widget actions() {
//     return Column(
//       children: [
//         SizedBox(
//           width: double.infinity,
//           height: 64,
//           child: ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: speaking ? const Color(0xff006a6a) : const Color(0xff2e3192),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//             ),
//             icon: Icon(speaking ? Icons.stop : Icons.volume_up, color: Colors.white),
//             label: Text(
//               speaking ? "Stop Speaking" : "Speak Result",
//               style: const TextStyle(color: Colors.white, fontSize: 20),
//             ),
//             onPressed: speakResult,
//           ),
//         ),
//         const SizedBox(height: 15),
//         SizedBox(
//           width: double.infinity,
//           height: 55,
//           child: OutlinedButton.icon(
//             icon: const Icon(Icons.history),
//             label: const Text("Scan History"),
//             onPressed: () {},
//           ),
//         )
//       ],
//     );
//   }

//   Widget insight() {
//     return Container(
//       padding: const EdgeInsets.all(15),
//       decoration: BoxDecoration(
//         color: const Color(0xffeff4ff),
//         borderRadius: BorderRadius.circular(12),
//         border: const Border(left: BorderSide(color: Color(0xff006a6a), width: 5)),
//       ),
//       child: Text(
//         detectedNote,
//         style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
//       ),
//     );
//   }

//   Widget bottomNav() {
//     return Positioned(
//       bottom: 0,
//       left: 0,
//       right: 0,
//       child: Container(
//         height: 80,
//         decoration: const BoxDecoration(
//           color: Color(0xffe6eeff),
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             navItem(Icons.camera, "Scan", true),
//             navItem(Icons.history, "History", false),
//             navItem(Icons.record_voice_over, "Voice", false),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget navItem(IconData icon, String text, bool active) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(icon, color: active ? const Color(0xff006a6a) : Colors.grey),
//         Text(text, style: TextStyle(color: active ? const Color(0xff006a6a) : Colors.grey))
//       ],
//     );
//   }

//   void _showHelpDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("How to Use"),
//         content: const Text(
//           "1. Point camera at Indian banknote\n"
//           "2. Hold steady inside the frame\n"
//           "3. App detects value automatically\n"
//           "4. Tap 'Speak Result' to hear value\n\n"
//           "Works for: ₹10, ₹20, ₹50, ₹100, ₹200, ₹500, ₹2000",
//         ),
//         actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it"))],
//       ),
//     );
//   }
// }