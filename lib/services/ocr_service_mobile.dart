import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String> recognizeImage(XFile image) async {
  final recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  try {
    final inputImage = InputImage.fromFilePath(image.path);
    final result = await recognizer.processImage(inputImage);
    return result.text;
  } finally {
    await recognizer.close();
  }
}