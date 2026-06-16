import 'dart:typed_data';
import 'package:screenshot/screenshot.dart';
import 'package:dio/dio.dart';

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

  /// Sends the captured binary PNG bytes using multipart/form-data via Dio.
  static Future<bool> _upload(String screenId, Uint8List bytes) async {
    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'screen_id': screenId,
        'image': MultipartFile.fromBytes(
          bytes,
          filename: 'screen_${screenId}_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      });

      final response = await dio.post(
        'https://viewsys.co.in/api/player/screenshot',
        data: formData,
        options: Options(
          headers: {
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        print('Screenshot uploaded successfully via Dio: ${response.data}');
        return true;
      } else {
        print('Screenshot upload failed with status: ${response.statusCode}, Data: ${response.data}');
      }
    } catch (e) {
      print('Screenshot upload exception via Dio: $e');
    }
    return false;
  }
}
