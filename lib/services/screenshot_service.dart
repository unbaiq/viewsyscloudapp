import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:http/http.dart' as http;

class ScreenshotService {
  /// Global screenshot controller to capture frame buffers wrapped in the Screenshot widget.
  static final ScreenshotController screenshotController = ScreenshotController();

  /// Captures the current player screen repaint boundary and sends PNG bytes to `/screenshot`.
  static Future<void> captureAndUpload(String screenId) async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture(pixelRatio: 2.0);
      if (imageBytes == null) {
        print('Screenshot capture failed: imageBytes is null.');
        return;
      }

      await _upload(screenId, imageBytes);
    } catch (e) {
      print('Screenshot capture error: $e');
    }
  }

  /// Sends the captured binary PNG bytes using multipart/form-data via http.
  static Future<bool> _upload(String screenId, Uint8List bytes) async {
    try {
      final uri = Uri.parse('https://cms.thelocads.com/api/player/screenshot');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.fields['screen_id'] = screenId;
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: 'screen_${screenId}_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        print('Screenshot uploaded successfully via http: $responseBody');
        return true;
      } else {
        print('Screenshot upload failed with status: ${response.statusCode}, Data: $responseBody');
      }
    } catch (e) {
      print('Screenshot upload exception via http: $e');
    }
    return false;
  }
}
