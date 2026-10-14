import 'dart:convert';
import 'dart:js_interop';

import 'package:image_picker/image_picker.dart';

@JS('ocrImageDataUrl')
external JSPromise<JSString> _ocrImageDataUrl(JSString dataUrl);

Future<String> recognizeImage(XFile image) async {
  final bytes = await image.readAsBytes();
  final base64Image = base64Encode(bytes);

  final dataUrl =
      'data:image/jpeg;base64,$base64Image';

  final result = await _ocrImageDataUrl(dataUrl.toJS).toDart;
  return result.toDart;
}